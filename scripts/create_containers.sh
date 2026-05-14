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
mkdir -p f1-telemetry/app
cd f1-telemetry

# Create the files
touch  .env Dockerfile docker-compose.yml requirements.txt app/main.py

# Populate the files

# .env
cat <<EOF > .env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres69
POSTGRES_DB=f1_telemetry
DATABASE_URL=postgresql://postgres:postgres69@db:5432/f1_telemetry
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

from fastapi import FastAPI, Response
from prometheus_client import Counter, generate_latest

app = FastAPI()

DATABASE_URL = os.getenv("DATABASE_URL")


# LOGGING (for Loki via Docker logs + Promtail)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)

logger = logging.getLogger("f1-telemetry")



# PROMETHEUS METRICS

REQUEST_COUNT = Counter("requests_total", "Total API requests")


@app.middleware("http")
async def count_requests(request, call_next):
    REQUEST_COUNT.inc()
    response = await call_next(request)
    return response


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type="text/plain")



# DB SETUP

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

    logger.info("Database table ensured")


create_table()



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



# DRIVERS CHAMPIONSHIP

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



# CONSTRUCTORS CHAMPIONSHIP

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
EOF

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
docker compose up -d --build

echo "Containers created and running."
echo "Access the FastAPI app with: curl http://localhost:8000"
echo ""
echo "View live telemetry-style F1 data:"
echo "curl http://localhost:8000/telemetry"
echo ""
echo "The telemetry table is now created automatically on container startup."
echo "The /telemetry endpoint automatically fetches and stores fresh OpenF1 data before returning results."
echo ""
echo "To stop the containers:"
echo "cd f1-telemetry && docker compose down"
echo ""
echo "To view logs:"
echo "cd f1-telemetry && docker compose logs -f"
echo ""
echo "To access the PostgreSQL database:"
echo "cd f1-telemetry && docker exec -it postgres_db psql -U postgres -d f1_telemetry"
echo ""
echo "Current running containers:"
docker ps