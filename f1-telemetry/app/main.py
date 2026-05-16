import os
import logging
import psycopg
import requests
import threading
import time

from fastapi import FastAPI, Response
from prometheus_client import Counter, Gauge, generate_latest

app = FastAPI()

DATABASE_URL = os.getenv("DATABASE_URL")

# LOGGING
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)

logger = logging.getLogger("f1-telemetry")

# PROMETHEUS METRICS
REQUEST_COUNT = Counter("requests_total", "Total API requests")

FASTEST_LAP = Gauge("fastest_lap_time", "Fastest lap time")
ACTIVE_DRIVERS = Gauge("active_drivers", "Number of active drivers")
AVG_LAP_TIME = Gauge("avg_lap_time", "Average lap time")


@app.middleware("http")
async def count_requests(request, call_next):
    REQUEST_COUNT.inc()
    response = await call_next(request)
    return response


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type="text/plain")


# DB INIT
def init_db():
    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS telemetry (
            id SERIAL PRIMARY KEY,
            driver_number INTEGER,
            driver_name TEXT,
            team_name TEXT,
            lap_number INTEGER,
            lap_time FLOAT,
            position INTEGER
        );
    """)

    conn.commit()
    conn.close()

    logger.info("Database ready")


init_db()


# BACKGROUND INGESTION LOOP
def ingestion_loop():
    while True:
        try:
            logger.info("Auto ingestion running...")
            ingest_data()
        except Exception as e:
            logger.error(f"Ingestion error: {e}")

        time.sleep(30)


@app.on_event("startup")
def start_background_tasks():
    thread = threading.Thread(target=ingestion_loop, daemon=True)
    thread.start()


# GET LATEST RACE SESSION
def get_latest_race_session():
    response = requests.get("https://api.openf1.org/v1/sessions")
    sessions = response.json()

    race_sessions = [
        s for s in sessions
        if s.get("session_type") == "Race"
    ]

    if not race_sessions:
        logger.warning("No race sessions found")
        return None

    latest = max(race_sessions, key=lambda x: x.get("date_start", ""))

    logger.info(f"Latest session key found: {latest.get('session_key')}")
    return latest.get("session_key")


# ROOT
@app.get("/")
def root():
    logger.info("Root endpoint hit")
    return {"status": "F1 telemetry API running"}


# TELEMETRY INGESTION
def ingest_data():
    logger.info("Starting ingestion")

    laps = requests.get("https://api.openf1.org/v1/laps?session_key=latest").json()
    positions = requests.get("https://api.openf1.org/v1/position?session_key=latest").json()
    drivers = requests.get("https://api.openf1.org/v1/drivers?session_key=latest").json()

    position_map = {
        p["driver_number"]: p.get("position")
        for p in positions
        if p.get("driver_number")
    }

    driver_map = {
        d["driver_number"]: {
            "name": d.get("full_name", "Unknown"),
            "team": d.get("team_name", "Unknown")
        }
        for d in drivers
        if d.get("driver_number")
    }

    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    inserted = 0

    for lap in laps[:15]:

        driver_number = lap.get("driver_number")
        lap_time = lap.get("lap_duration")
        lap_number = lap.get("lap_number")

        if not driver_number or not lap_time:
            continue

        driver_info = driver_map.get(driver_number, {})
        driver_name = driver_info.get("name", "Unknown")
        team_name = driver_info.get("team", "Unknown")

        position = position_map.get(driver_number)

        cur.execute("""
            SELECT 1 FROM telemetry
            WHERE driver_number = %s AND lap_number = %s
        """, (driver_number, lap_number))

        if cur.fetchone():
            continue

        cur.execute("""
            INSERT INTO telemetry (
                driver_number,
                driver_name,
                team_name,
                lap_number,
                lap_time,
                position
            )
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            driver_number,
            driver_name,
            team_name,
            lap_number,
            lap_time,
            position
        ))

        inserted += 1

    conn.commit()
    conn.close()

    # PROMETHEUS UPDATE
    conn2 = psycopg.connect(DATABASE_URL)
    cur2 = conn2.cursor()

    cur2.execute("SELECT MIN(lap_time) FROM telemetry")
    FASTEST_LAP.set(cur2.fetchone()[0] or 0)

    cur2.execute("SELECT COUNT(DISTINCT driver_number) FROM telemetry")
    ACTIVE_DRIVERS.set(cur2.fetchone()[0] or 0)

    cur2.execute("SELECT AVG(lap_time) FROM telemetry")
    AVG_LAP_TIME.set(cur2.fetchone()[0] or 0)

    conn2.close()

    logger.info(f"Ingestion complete. Inserted {inserted} rows")

    return inserted


# TELEMETRY
@app.get("/telemetry")
def get_telemetry():
    logger.info("Telemetry endpoint called")

    ingest_data()

    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("""
        SELECT driver_number, driver_name, team_name,
               lap_number, lap_time, position
        FROM telemetry
        ORDER BY id DESC
    """)

    rows = cur.fetchall()
    conn.close()

    leaderboard = {}

    for r in rows:
        if r[0] not in leaderboard:
            leaderboard[r[0]] = {
                "driver_number": r[0],
                "driver_name": r[1],
                "team_name": r[2],
                "lap_number": r[3],
                "lap_time": r[4],
                "position": r[5],
            }

    data = list(leaderboard.values())

    data.sort(
        key=lambda x: (
            x["position"] if x["position"] is not None else 999,
            x["lap_time"] if x["lap_time"] is not None else 9999
        )
    )

    logger.info(f"Returned {len(data)} leaderboard entries")

    return {
        "mode": "live_leaderboard",
        "data": data
    }


# CHAMPIONSHIPS
@app.get("/championship/drivers")
def drivers_championship():

    session_key = get_latest_race_session()

    if not session_key:
        return {"error": "No race session found"}

    response = requests.get(
        f"https://api.openf1.org/v1/championship_drivers?session_key={session_key}"
    )

    data = response.json()
    data.sort(key=lambda x: x.get("points_current", 0), reverse=True)

    logger.info("Drivers championship fetched")

    return {
        "session_key": session_key,
        "mode": "drivers_championship",
        "data": data
    }


@app.get("/championship/constructors")
def constructors_championship():

    session_key = get_latest_race_session()

    if not session_key:
        return {"error": "No race session found"}

    response = requests.get(
        f"https://api.openf1.org/v1/championship_teams?session_key={session_key}"
    )

    data = response.json()
    data.sort(key=lambda x: x.get("points_current", 0), reverse=True)

    logger.info("Constructors championship fetched")

    return {
        "session_key": session_key,
        "mode": "constructors_championship",
        "data": data
    }


# METRICS ENDPOINT
@app.get("/metrics/telemetry")
def telemetry_metric():

    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("SELECT COUNT(DISTINCT driver_number) FROM telemetry;")
    result = cur.fetchone()[0]

    conn.close()

    return {
        "active_drivers": result
    }