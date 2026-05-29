#!/bin/bash

# For the VM you NEED to run as root, otherwise this wont work
if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo: sudo $0"
  echo "Use 'sudo -i' to get a root shell and then run the script. You will get 'root@pitwall-vm:~# '"
  echo "If you're uploading the script, move it to the root user's home directory: sudo mv ~/create_containers.sh /root/."
  echo "Use chmod +x create_containers.sh to make it executable, then run it: ./create_containers.sh"
  exit 1
fi

# Create the f1-telemetry directory for files to be put in
echo "==============================================================="
echo "Creating f1-telemetry directory and files..."
echo "==============================================================="

mkdir -p f1-telemetry/app
cd f1-telemetry

# Create the files
touch  .env Dockerfile docker-compose.yml requirements.txt app/main.py

# Populate the files
echo "==============================================================="
echo "Populating all files with content..."
echo "==============================================================="


# .env
cat <<EOF > .env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=change_this_password
POSTGRES_DB=f1_telemetry
DATABASE_URL=postgresql://postgres:change_this_password@db:5432/f1_telemetry
EOF

# Dockerfile
cat <<EOF > Dockerfile
FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# requirements.txt
cat <<EOF > requirements.txt
fastapi
uvicorn[standard]
psycopg[binary]
requests
prometheus_client
EOF

# app/main.py
cat <<EOF > app/main.py
import os
import logging
import psycopg
import requests
import threading
import time
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import FastAPI, Response
from prometheus_client import Counter, Gauge, generate_latest, Info


app = FastAPI()

DATABASE_URL = os.getenv("DATABASE_URL")
START_TIME = time.time()

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

CURRENT_RACE_LEADER = Info(
    "current_race_leader",
    "Current race leader"
)

FASTEST_DRIVER = Gauge(
    "fastest_driver_lap_time",
    "Fastest driver lap time",
    ["driver_full"]
)

FASTEST_TEAM = Info(
    "fastest_team",
    "Team with fastest average lap"
)

TEAM_AVG_LAP = Gauge(
    "team_average_lap_time",
    "Average lap time per team",
    ["team"]
)

LAP_COUNT = Gauge(
    "driver_lap_count",
    "Lap count per driver",
    ["driver"]
)

# SYSTEM INFO
CURRENT_SESSION = Info(
    "current_session_info",
    "Current session information"
)

SESSION_INFO = Info("session_info", "Current F1 session info")

INGESTION_COUNT = Counter(
    "ingestion_cycles_total",
    "Total ingestion cycles"
)

FAILED_API_REQUESTS = Counter(
    "failed_api_requests_total",
    "Failed API requests"
)

OPENF1_RESPONSE_TIME = Gauge(
    "openf1_response_time_seconds",
    "OpenF1 API response time"
)

DB_QUERY_DURATION = Gauge(
    "db_query_duration_seconds",
    "Database query duration"
)

API_UPTIME = Gauge(
    "api_uptime_seconds",
    "API uptime in seconds"
)

LAST_INGESTION_TIME = Gauge(
    "last_ingestion_timestamp",
    "Last successful ingestion timestamp"
)


# ENDPOINT MIDDLEWARE

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
            FAILED_API_REQUESTS.inc()

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

    INGESTION_COUNT.inc()
    api_start = time.time()

    laps_response = requests.get(
    "https://api.openf1.org/v1/laps?session_key=latest"
    )

    OPENF1_RESPONSE_TIME.set(
        time.time() - api_start
    )

    laps = laps_response.json()
    positions = requests.get("https://api.openf1.org/v1/position?session_key=latest").json()
    drivers = requests.get("https://api.openf1.org/v1/drivers?session_key=latest").json()
    session_info = requests.get("https://api.openf1.org/v1/sessions?session_key=latest").json()

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

    if session_info:
        current = session_info[0]

        CURRENT_SESSION.info({
            "race_name": current.get("session_name", "Unknown"),
            "session_type": current.get("session_type", "Unknown"),
            "country": current.get("country_name", "Unknown"),
            "circuit": current.get("circuit_short_name", "Unknown")
        })

    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    inserted = 0

    for lap in laps:

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

    cur2.execute("""
        SELECT driver_name, MIN(lap_time)
        FROM telemetry
        GROUP BY driver_name
        ORDER BY MIN(lap_time)
        LIMIT 1
    """)

    fastest_driver = cur2.fetchone()

    if fastest_driver:
        FASTEST_DRIVER.labels(
            driver_full=fastest_driver[0]
        ).set(fastest_driver[1])


    cur2.execute("""
        SELECT team_name, AVG(lap_time) AS avg_time
        FROM telemetry
        GROUP BY team_name
    """)

    teams = cur2.fetchall()

    fastest_team_name = None
    fastest_team_time = None

    for team_name, avg_time in teams:
        TEAM_AVG_LAP.labels(team=team_name).set(avg_time)

        if fastest_team_time is None or avg_time < fastest_team_time:
            fastest_team_time = avg_time
            fastest_team_name = team_name

    if fastest_team_name:
        FASTEST_TEAM.info({
            "team": fastest_team_name,
            "avg_lap_time": str(fastest_team_time)
        })

    cur2.execute("""
        SELECT driver_name, COUNT(*) as laps
        FROM telemetry
        GROUP BY driver_name
    """)

    for driver_name, laps in cur2.fetchall():
        LAP_COUNT.labels(driver=driver_name).set(laps)

    LAST_INGESTION_TIME.set(time.time() * 1000)
    conn2.close()

    logger.info(f"Ingestion complete. Inserted {inserted} rows")

    return inserted

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

    for entry in data:
        laps = entry["lap_number"] or 0
        pos = entry["position"]

        if laps == 0:
            entry["status"] = "DNS"
        elif entry["position"] is None:
            entry["status"] = "DNF"
        else:
            entry["status"] = "Finished"

        entry["display_position"] = (
            pos if entry["status"] == "Finished" else entry["status"]
        )

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

    session_key = "latest"

    if not session_key:
        return {"error": "No race session found"}

    response = requests.get(
        f"https://api.openf1.org/v1/championship_drivers?session_key={session_key}"
    )

    data = response.json()

    drivers = requests.get(
        "https://api.openf1.org/v1/drivers?session_key=latest"
    ).json()

    driver_map = {
        d["driver_number"]: d.get("full_name", "Unknown")
        for d in drivers
    }

    for d in data:
        d["driver_name"] = driver_map.get(d["driver_number"], "Unknown")

    if isinstance(data, dict):
        data = [data]

    data.sort(
        key=lambda x: x.get("points_current", 0),
        reverse=True
    )

    logger.info("Drivers championship fetched")

    return {
        "session_key": session_key,
        "mode": "drivers_championship",
        "data": data
    }


@app.get("/championship/constructors")
def constructors_championship():

    session_key = "latest"

    if not session_key:
        return {"error": "No race session found"}

    response = requests.get(
        f"https://api.openf1.org/v1/championship_teams?session_key={session_key}"
    )

    data = response.json()

    if isinstance(data, dict):
        data = [data]

    data.sort(
        key=lambda x: x.get("points_current", 0),
        reverse=True
    )

    logger.info("Constructors championship fetched")

    return {
        "session_key": session_key,
        "mode": "constructors_championship",
        "data": data
    }


# METRICS ENDPOINT

@app.get("/session/info")
def session_info():

    response = requests.get(
        "https://api.openf1.org/v1/sessions?session_key=latest"
    )

    data = response.json()

    if not data:
        return {"error": "No session found"}

    session = data[0]

    meeting_response = requests.get(
        f"https://api.openf1.org/v1/meetings?meeting_key={session['meeting_key']}"
    )

    meeting_data = meeting_response.json()

    if meeting_data:
        meeting = meeting_data[0]
        meeting_name = meeting.get("meeting_name", "Unknown")

        session_start_raw = session.get("date_start", None)

        if session_start_raw:
            meeting_start = datetime.fromisoformat(
                session_start_raw.replace("Z", "+00:00")
            ).astimezone(
                ZoneInfo("Pacific/Auckland")
            ).strftime("%A %d %B %Y %H:%M %Z")
        else:
            meeting_start = None
    else:
        meeting_name = "Unknown"
        meeting_start = None


    SESSION_INFO.info({
        "race_name": meeting_name,
        "session_type": session.get("session_type", "Unknown"),
        "circuit": session.get("circuit_short_name", "Unknown"),
        "country": session.get("country_name", "Unknown"),
        "meeting_start": meeting_start
    })

    return {
        "race_name": meeting_name,
        "session_type": session.get("session_type"),
        "circuit": session.get("circuit_short_name"),
        "country": session.get("country_name"),
        "meeting_start": meeting_start
    }

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
EOF

# -----------------------------
# Create Docker network
# -----------------------------
echo "==========================================================="
echo "Creating Docker network if missing..."
echo "==========================================================="

docker network inspect telemetry-network >/dev/null 2>&1 || \
docker network create telemetry-network


# docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  web:
    build: .
    image: f1-telemetry-api:1.0
    container_name: fastapi_app

    env_file:
      - .env

    ports:
      - "8000:8000"

    depends_on:
      db:
        condition: service_healthy

    volumes:
      - .:/app

    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

    restart: always

    networks:
      - telemetry-network


  db:
    image: postgres:18
    container_name: postgres_db

    env_file:
      - .env

    ports:
      - "5432:5432"

    volumes:
      - pgdata:/var/lib/postgresql

    restart: always

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d f1_telemetry"]
      interval: 10s
      timeout: 5s
      retries: 5

    networks:
      - telemetry-network


volumes:
  pgdata:


networks:
  telemetry-network:
    external: true
EOF

# Run the containers
echo "==============================================================="
echo "Building and starting containers with Docker Compose..."
echo "==============================================================="

docker compose up -d --build

echo "=============================================================="
echo " Container Stack "
echo "=============================================================="
echo "Containers created and running."
echo "Access the FastAPI app with: curl http://localhost:8000"
echo ""
echo "View live telemetry-style F1 data:"
echo "curl http://localhost:8000/telemetry"
echo ""
echo "Other FastAPI endpoints available:"
echo "curl http://localhost:8000/championship/drivers"
echo "curl http://localhost:8000/championship/constructors"
echo "curl http://localhost:8000/session/info"
echo ""
echo "Prometheus metrics available at: http://localhost:8000/metrics"
echo "Also available at http://localhost:8000/metrics/telemetry for custom telemetry metrics"
echo ""

echo "The telemetry table is now created automatically on container startup."
echo "The /telemetry endpoint automatically fetches and stores fresh OpenF1 data before returning results."
echo ""
echo " To see running containers: "
echo "docker ps"
echo ""
echo "To stop the containers:"
echo "cd f1-telemetry && docker compose down"
echo ""
echo "To rebuild the containers after changes:"
echo "cd f1-telemetry && docker compose up -d --build"
echo "To view logs:"
echo "cd f1-telemetry && docker compose logs -f"
echo ""
echo "To access the PostgreSQL database:"
echo "cd f1-telemetry && docker exec -it postgres_db psql -U postgres -d f1_telemetry"
echo ""
echo "=============================================================="