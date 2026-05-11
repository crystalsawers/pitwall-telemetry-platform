import os
from fastapi import FastAPI
import psycopg
import requests

app = FastAPI()

DATABASE_URL = os.getenv("DATABASE_URL")


def create_table():
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


create_table()


@app.get("/")
def root():
    return {"status": "F1 telemetry API running"}


@app.get("/db-test")
def db_test():
    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("SELECT version();")
    result = cur.fetchone()

    conn.close()

    return {"postgres": result}


@app.post("/telemetry/add")
def add_telemetry():

    response = requests.get(
        "https://api.openf1.org/v1/laps?session_key=latest"
    )

    data = response.json()

    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    inserted = 0

    for lap in data[:10]:

        driver_number = lap.get("driver_number")
        lap_time = lap.get("lap_duration")
        lap_number = lap.get("lap_number")
        position = lap.get("position")

        if lap_time is None or driver_number is None:
            continue

        driver_response = requests.get(
            f"https://api.openf1.org/v1/drivers?session_key=latest&driver_number={driver_number}"
        )

        driver_data = driver_response.json()

        if driver_data:
            driver_name = driver_data[0].get("full_name", "Unknown")
            team_name = driver_data[0].get("team_name", "Unknown")
        else:
            driver_name = "Unknown"
            team_name = "Unknown"

        cur.execute("""
            INSERT INTO telemetry (
                driver_number,
                driver_name,
                team_name,
                lap_number,
                lap_time,
                position
            )
            VALUES (%s, %s, %s, %s, %s, %s);
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

    return {"status": f"{inserted} rows inserted"}


@app.get("/telemetry")
def get_telemetry():

    add_telemetry()

    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("""
        SELECT
            driver_number,
            driver_name,
            team_name,
            lap_number,
            lap_time,
            position
        FROM telemetry
        ORDER BY id DESC
    """)

    rows = cur.fetchall()
    conn.close()

    leaderboard = {}

    for r in rows:
        driver_number = r[0]

        if driver_number not in leaderboard:
            leaderboard[driver_number] = {
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

    return {
        "mode": "live_leaderboard",
        "data": data
    }