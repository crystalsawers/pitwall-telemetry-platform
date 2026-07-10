#!/bin/bash

# For the VM you NEED to run as root, otherwise this wont work
if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo: sudo $0"
  echo "Use 'sudo -i' to get a root shell and then run the script. You will get 'root@pitwall-vm:~# '"
  echo "If you're uploading the script, move it to the root user's home directory: mv ~/basic_setup.sh /root/."
  echo "Use chmod +x basic_setup.sh to make it executable, then run it with sudo: ./basic_setup.sh"
  exit 1
fi

# Update and upgrade the system, then install necessary base packages

echo "=========================================================================="
echo "Updating and upgrading the system, and installing necessary packages..."
echo "=========================================================================="

apt update &&  apt upgrade -y
apt install -y git curl jq ufw ca-certificates

# Enable UFW and allow necessary ports (e.g., SSH, HTTP, HTTPS)

echo "=========================================================================="
echo "Configuring UFW firewall..."
echo "=========================================================================="

RULES=(
  "OpenSSH"
  "80/tcp"
  "443/tcp"
  "8000/tcp"
  "5432/tcp"
)

for rule in "${RULES[@]}"; do
  ufw allow "$rule"
done

ufw --force enable
ufw status verbose

# Setup Docker Apt repository (this is from Docker's official installation instructions for Ubuntu)

echo "=========================================================================="
echo "Setting up Docker repository and installing Docker Engine..."
echo "=========================================================================="

# Add Docker's official GPG key:
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Install Docker Engine
apt update # Important! As it will not install at all if you don't do this first
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify Docker is running
echo "=========================================================================="
echo "Verifying Docker installation..."
echo "=========================================================================="
systemctl status docker --no-pager

if [ $? -ne 0 ]; then
    echo "Docker is not running. Starting Docker."
    systemctl start docker
    systemctl enable docker
    systemctl status docker --no-pager
fi

docker --version

echo "=========================================================================="
echo "Basic setup completed. "
echo "=========================================================================="

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


try:
    init_db()
except Exception as e:
    logger.error(f"DB init failed: {e}")


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

echo "=========================================="
echo "F1 Telemetry Monitoring Stack Setup"
echo "=========================================="

# -----------------------------
# Ensure script runs inside f1-telemetry
# -----------------------------
CURRENT_DIR=$(basename "$PWD")

if [ "$CURRENT_DIR" != "f1-telemetry" ]; then

    if [ -d "$HOME/f1-telemetry" ]; then
        echo "[+] Switching to $HOME/f1-telemetry"
        cd "$HOME/f1-telemetry"
    else
        echo "[ERROR] Could not find f1-telemetry directory in home folder."
        exit 1
    fi

fi

echo "[+] Current directory: $(pwd)"

# -----------------------------
# Create monitoring directories
# -----------------------------
echo "==========================================================="
echo "Creating monitoring directories..."
echo "==========================================================="

mkdir -p monitoring/{prometheus,grafana/provisioning,loki,promtail}
# Add subdirectories for Grafana provisioning
mkdir -p monitoring/grafana/provisioning/datasources
mkdir -p monitoring/grafana/provisioning/dashboards
mkdir -p monitoring/grafana/provisioning/dashboards-json


echo "[+] Done creating monitoring directories."

# -----------------------------
# Create Prometheus config
# -----------------------------
echo "==========================================================="
echo "Creating Prometheus configuration..."
echo "==========================================================="

cat <<EOF > monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'fastapi'
    static_configs:
      - targets: ['fastapi_app:8000']
EOF

echo "[+] Done creating Prometheus configuration."

# -----------------------------
# Create Loki config
# -----------------------------
echo "==========================================================="
echo "Creating Loki configuration..."
echo "==========================================================="

cat <<EOF > monitoring/loki/config.yml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
EOF

echo "[+] Done creating Loki configuration."

# -----------------------------
# Create Promtail config
# -----------------------------
echo "==========================================================="
echo "Creating Promtail configuration..."
echo "==========================================================="

cat <<EOF > monitoring/promtail/config.yml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: fastapi
          __path__: /var/lib/docker/containers/*/*-json.log
EOF

echo "[+] Done creating Promtail configuration."

#-------------------------------
# Create Grafana provisioning config
#-------------------------------

# Datasources:
# Prometheus, Loki, and Infinity (datasource has a name of yesoreyeram-infinity-datasource when editing the dash panel)

echo "==========================================================="
echo "Datasource configuration for Grafana..."
echo "==========================================================="
cat <<EOF > monitoring/grafana/provisioning/datasources/datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    uid: prom-main
    isDefault: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    uid: loki-main

  - name: Infinity
    type: yesoreyeram-infinity-datasource
    access: proxy
    uid: infinity-main
EOF

echo "[+] Done creating Grafana datasource configuration."

echo "==========================================================="
echo "Creating Grafana dashboard provisioning file..."
echo "==========================================================="

cat <<EOF > monitoring/grafana/provisioning/dashboards/dashboards.yml
apiVersion: 1

providers:
  - name: "F1 Dashboards"
    orgId: 1
    folder: "F1 Telemetry"
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF

echo "[+] Done creating Grafana dashboard provisioning file."

echo "==========================================================="
echo "Creating Grafana dashboard JSON: F1 Telemetry Data..."
echo "==========================================================="

cat <<EOF > monitoring/grafana/provisioning/dashboards-json/f1-telemetry-data.json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "yesoreyeram-infinity-datasource",
        "uid": "infinity-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "purple",
                "value": 0
              }
            ]
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "circuit",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Circuit:"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "country",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Country:"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "race_name",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Race:"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "session_type",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Session:"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "meeting_start",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Race Time:"
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 9,
        "w": 10,
        "x": 0,
        "y": 0
      },
      "id": 6,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "horizontal",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "/.*/",
          "values": false
        },
        "showPercentChange": false,
        "text": {
          "titleSize": 20,
          "valueSize": 20
        },
        "textMode": "value_and_name",
        "wideLayout": true
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "columns": [],
          "datasource": {
            "type": "yesoreyeram-infinity-datasource",
            "uid": "infinity-main"
          },
          "filters": [],
          "format": "table",
          "global_query_id": "",
          "parser": "backend",
          "refId": "A",
          "root_selector": "",
          "source": "url",
          "type": "json",
          "url": "http://fastapi_app:8000/session/info",
          "url_options": {
            "data": "",
            "method": "GET"
          }
        }
      ],
      "title": "Session Info",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "#d977bc",
                "value": 0
              }
            ]
          },
          "unit": "clocks"
        }
      },
      "gridPos": {
        "h": 9,
        "w": 7,
        "x": 10,
        "y": 0
      },
      "id": 9,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "limit": 1,
          "values": false
        },
        "showPercentChange": false,
        "textMode": "value_and_name",
        "wideLayout": false
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "exemplar": false,
          "expr": "bottomk(1, team_average_lap_time)",
          "instant": true,
          "legendFormat": "{{team}}",
          "range": false,
          "refId": "A"
        }
      ],
      "title": "Fastest Team",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              }
            ]
          },
          "unit": "clocks"
        }
      },
      "gridPos": {
        "h": 9,
        "w": 7,
        "x": 17,
        "y": 0
      },
      "id": 7,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "center",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "text": {
          "valueSize": 40
        },
        "textMode": "value_and_name",
        "wideLayout": false
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "fastest_driver_lap_time",
          "legendFormat": "{{driver_full}}",
          "instant": true,
          "range": false,
          "refId": "A"
        }
      ],
      "title": "Driver with Fastest Lap",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "continuous-GrYlRd"
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              }
            ]
          }
        }
      },
      "gridPos": {
        "h": 9,
        "w": 12,
        "x": 0,
        "y": 9
      },
      "id": 8,
      "options": {
        "displayMode": "lcd",
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": false
        },
        "maxVizHeight": 300,
        "minVizHeight": 16,
        "minVizWidth": 8,
        "namePlacement": "auto",
        "orientation": "horizontal",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showUnfilled": true,
        "sizing": "auto",
        "valueMode": "color"
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "team_average_lap_time",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Team Average Lap Time",
      "transformations": [
        {
          "id": "labelsToFields",
          "options": {
            "keepLabels": [
              "team"
            ],
            "valueLabel": "team"
          }
        }
      ],
      "type": "bargauge"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "#EAB839",
                "value": 100
              },
              {
                "color": "red",
                "value": 105
              }
            ]
          },
          "unit": "clocks"
        }
      },
      "gridPos": {
        "h": 9,
        "w": 12,
        "x": 12,
        "y": 9
      },
      "id": 1,
      "options": {
        "barShape": "flat",
        "barWidthFactor": 0.3,
        "effects": {
          "barGlow": false,
          "centerGlow": false,
          "gradient": true
        },
        "endpointMarker": "point",
        "minVizHeight": 75,
        "minVizWidth": 75,
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "segmentCount": 1,
        "segmentSpacing": 0.3,
        "shape": "gauge",
        "showThresholdLabels": false,
        "showThresholdMarkers": false,
        "sizing": "auto",
        "sparkline": true,
        "textMode": "auto"
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "avg_lap_time",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Average Lap Time",
      "type": "gauge"
    },
    {
      "datasource": {
        "type": "yesoreyeram-infinity-datasource",
        "uid": "infinity-main"
      },
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": "auto",
            "cellOptions": {
              "type": "auto"
            },
            "footer": {
              "reducers": []
            },
            "inspect": false
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              }
            ]
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "driver_name",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Driver"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "driver_number",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Driver Number"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "lap_number",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Laps"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "lap_time",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Lap Time"
              },
              {
                "id": "unit",
                "value": "clocks"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "position",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Position"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "team_name",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Team"
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "Driver Number"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 123
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "Position"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 66
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 12,
        "w": 24,
        "x": 0,
        "y": 18
      },
      "id": 3,
      "options": {
        "cellHeight": "sm",
        "showHeader": true,
        "sortBy": []
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "columns": [
            {
              "selector": "driver_name",
              "text": "Driver",
              "type": "string"
            },
            {
              "selector": "driver_number",
              "text": "Driver Number",
              "type": "string"
            },
            {
              "selector": "team_name",
              "text": "Team",
              "type": "string"
            },
            {
              "selector": "position",
              "text": "Position",
              "type": "string"
            },
            {
              "selector": "lap_time",
              "text": "Lap Time",
              "type": "string"
            },
            {
              "selector": "lap_number",
              "text": "Lap Number",
              "type": "string"
            }
          ],
          "datasource": {
            "type": "yesoreyeram-infinity-datasource",
            "uid": "infinity-main"
          },
          "filters": [],
          "format": "table",
          "global_query_id": "",
          "parser": "backend",
          "refId": "A",
          "root_selector": "data",
          "source": "url",
          "type": "json",
          "url": "http://fastapi_app:8000/telemetry",
          "url_options": {
            "data": "",
            "method": "GET"
          }
        }
      ],
      "title": "Race Leaderboard",
      "transformations": [
        {
          "id": "organize",
          "options": {
            "excludeByName": {},
            "includeByName": {},
            "indexByName": {
              "Driver": 1,
              "Driver Number": 2,
              "Lap Number": 5,
              "Lap Time": 4,
              "Position": 0,
              "Team": 3
            },
            "renameByName": {}
          }
        }
      ],
      "type": "table"
    },
    {
      "datasource": {
        "type": "yesoreyeram-infinity-datasource",
        "uid": "infinity-main"
      },
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": "auto",
            "cellOptions": {
              "type": "auto"
            },
            "footer": {
              "reducers": []
            },
            "inspect": false
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Position"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 102
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 13,
        "w": 12,
        "x": 0,
        "y": 30
      },
      "id": 5,
      "options": {
        "cellHeight": "sm",
        "showHeader": true,
        "sortBy": [
          {
            "desc": true,
            "displayName": "driver_name"
          }
        ]
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "columns": [
            {
              "selector": "driver_name",
              "text": "driver_name",
              "type": "string"
            },
            {
              "selector": "points_current",
              "text": "points_current",
              "type": "string"
            },
            {
              "selector": "position_current",
              "text": "position_current",
              "type": "string"
            }
          ],
          "datasource": {
            "type": "yesoreyeram-infinity-datasource",
            "uid": "infinity-main"
          },
          "filters": [],
          "format": "table",
          "global_query_id": "",
          "parser": "backend",
          "refId": "A",
          "root_selector": "data",
          "source": "url",
          "type": "json",
          "url": "http://fastapi_app:8000/championship/drivers",
          "url_options": {
            "data": "",
            "method": "GET"
          }
        }
      ],
      "title": "Drivers Championship",
      "transformations": [
        {
          "id": "organize",
          "options": {
            "excludeByName": {
              "driver_number": true,
              "meeting_key": true,
              "points_start": true,
              "position_start": true,
              "session_key": true
            },
            "includeByName": {},
            "indexByName": {
              "driver_name": 1,
              "driver_number": 4,
              "meeting_key": 3,
              "points_current": 2,
              "points_start": 5,
              "position_current": 0,
              "position_start": 6,
              "session_key": 7
            },
            "renameByName": {
              "driver_name": "Driver",
              "points_current": "Points",
              "position_current": "Position"
            }
          }
        }
      ],
      "type": "table"
    },
    {
      "datasource": {
        "type": "yesoreyeram-infinity-datasource",
        "uid": "infinity-main"
      },
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": "auto",
            "cellOptions": {
              "type": "auto"
            },
            "footer": {
              "reducers": []
            },
            "inspect": false
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Position"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 240
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "Team"
            },
            "properties": [
              {
                "id": "custom.width",
                "value": 216
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 13,
        "w": 12,
        "x": 12,
        "y": 30
      },
      "id": 4,
      "options": {
        "cellHeight": "sm",
        "showHeader": true
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "columns": [
            {
              "selector": "team_name",
              "text": "team_name",
              "type": "string"
            },
            {
              "selector": "position_current",
              "text": "position_current",
              "type": "string"
            },
            {
              "selector": "points_current",
              "text": "points_current",
              "type": "string"
            }
          ],
          "datasource": {
            "type": "yesoreyeram-infinity-datasource",
            "uid": "infinity-main"
          },
          "filters": [],
          "format": "table",
          "global_query_id": "",
          "parser": "backend",
          "refId": "A",
          "root_selector": "data",
          "source": "url",
          "type": "json",
          "url": "http://fastapi_app:8000/championship/constructors",
          "url_options": {
            "data": "",
            "method": "GET"
          }
        }
      ],
      "title": "Constructors Championship",
      "transformations": [
        {
          "id": "organize",
          "options": {
            "excludeByName": {},
            "includeByName": {},
            "indexByName": {
              "points_current": 2,
              "position_current": 0,
              "team_name": 1
            },
            "renameByName": {
              "points_current": "Points",
              "position_current": "Position",
              "team_name": "Team"
            }
          }
        }
      ],
      "type": "table"
    }
  ],
  "preload": false,
  "refresh": "",
  "schemaVersion": 42,
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "browser",
  "title": "F1 Telemetry Data",
  "version": 37,
  "uid": "adhx9fq",
  "id": 2159133791170560
}
EOF

echo "[+] Done creating Grafana dashboard JSON for F1 Telemetry Data."

echo "==========================================================="
echo "Creating Grafana dashboard JSON: F1 Telemetry System..."
echo "==========================================================="

cat <<EOF > monitoring/grafana/provisioning/dashboards-json/f1-telemetry-system.json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "options": {
                "0": {
                  "index": 1,
                  "text": "DOWN"
                },
                "1": {
                  "index": 0,
                  "text": "UP"
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 0
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          }
        }
      },
      "gridPos": {
        "h": 7,
        "w": 5,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "up{job=\"fastapi\"}",
          "instant": false,
          "legendFormat": "__auto",
          "range": true,
          "refId": "B"
        }
      ],
      "title": "FastAPI Status",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "mappings": [
            {
              "options": {
                "0": {
                  "index": 0,
                  "text": "DOWN"
                },
                "1": {
                  "index": 1,
                  "text": "UP"
                }
              },
              "type": "value"
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 0
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          }
        }
      },
      "gridPos": {
        "h": 7,
        "w": 5,
        "x": 5,
        "y": 0
      },
      "id": 3,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "up{job=\"fastapi\"}",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "API Uptime",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "{instance=\"fastapi_app:8000\", job=\"fastapi\"}",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "FastAPI App"
              },
              {
                "id": "mappings",
                "value": [
                  {
                    "options": {
                      "0": {
                        "index": 1,
                        "text": "DOWN"
                      },
                      "1": {
                        "index": 0,
                        "text": "UP"
                      }
                    },
                    "type": "value"
                  }
                ]
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "{instance=\"localhost:9090\", job=\"prometheus\"}",
              "scope": "series"
            },
            "properties": [
              {
                "id": "displayName",
                "value": "Prometheus"
              },
              {
                "id": "mappings",
                "value": [
                  {
                    "options": {
                      "0": {
                        "index": 1,
                        "text": "DOWN"
                      },
                      "1": {
                        "index": 0,
                        "text": "UP"
                      }
                    },
                    "type": "value"
                  }
                ]
              }
            ]
          }
        ]
      },
      "gridPos": {
        "h": 7,
        "w": 14,
        "x": 10,
        "y": 0
      },
      "id": 7,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "textMode": "auto",
        "wideLayout": true
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "up",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Prometheus Metrics Health",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "barWidthFactor": 0.6,
            "drawStyle": "line",
            "fillOpacity": 0,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "linear",
            "lineStyle": {
              "fill": "solid"
            },
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "showValues": false,
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "reqps"
        }
      },
      "gridPos": {
        "h": 7,
        "w": 12,
        "x": 0,
        "y": 7
      },
      "id": 2,
      "options": {
        "annotations": {
          "clustering": -1,
          "multiLane": false
        },
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": false
        },
        "tooltip": {
          "hideZeros": false,
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "sum(rate(requests_total[1m]))",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "API Request Rate",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "description": "Flat lines means it's healthy, and any spikes mean that there are some failed requests",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "barWidthFactor": 0.6,
            "drawStyle": "line",
            "fillOpacity": 25,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "showValues": false,
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        }
      },
      "gridPos": {
        "h": 7,
        "w": 12,
        "x": 12,
        "y": 7
      },
      "id": 4,
      "options": {
        "annotations": {
          "clustering": -1,
          "multiLane": false
        },
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "hideZeros": false,
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "increase(failed_api_requests_total[5m])",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Failed API Requests",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "loki",
        "uid": "loki-main"
      },
      "gridPos": {
        "h": 8,
        "w": 11,
        "x": 0,
        "y": 14
      },
      "id": 5,
      "options": {
        "dedupStrategy": "none",
        "enableInfiniteScrolling": false,
        "enableLogDetails": true,
        "prettifyLogMessage": true,
        "showControls": false,
        "showFieldSelector": false,
        "showLevel": true,
        "showTime": false,
        "sortOrder": "Descending",
        "timestampResolution": "ms",
        "unwrappedColumns": false,
        "wrapLogMessage": false
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "loki",
            "uid": "loki-main"
          },
          "direction": "backward",
          "editorMode": "code",
          "expr": "{service_name=~\".+\"}",
          "queryType": "range",
          "refId": "A"
        }
      ],
      "title": "Loki Logs",
      "type": "logs"
    },
    {
      "datasource": {
        "type": "loki",
        "uid": "loki-main"
      },
      "gridPos": {
        "h": 8,
        "w": 13,
        "x": 11,
        "y": 14
      },
      "id": 6,
      "options": {
        "dedupStrategy": "none",
        "enableInfiniteScrolling": false,
        "enableLogDetails": true,
        "prettifyLogMessage": true,
        "showControls": false,
        "showFieldSelector": false,
        "showLevel": true,
        "showTime": false,
        "sortOrder": "Descending",
        "timestampResolution": "ms",
        "unwrappedColumns": false,
        "wrapLogMessage": false
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "loki",
            "uid": "loki-main"
          },
          "direction": "backward",
          "editorMode": "code",
          "expr": "{service_name=~\".+\"} |~ \"level=(warn|error)\"",
          "queryType": "range",
          "refId": "A"
        }
      ],
      "title": "Loki Log Errors & Warnings",
      "type": "logs"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "barWidthFactor": 0.6,
            "drawStyle": "line",
            "fillOpacity": 25,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "showValues": false,
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        }
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 22
      },
      "id": 8,
      "options": {
        "annotations": {
          "clustering": -1,
          "multiLane": false
        },
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "hideZeros": false,
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "increase(ingestion_cycles_total[5m])",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Data Ingestion Cycle Count",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "dateTimeAsIso"
        }
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 22
      },
      "id": 9,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "percentChangeColorMode": "standard",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "showPercentChange": false,
        "textMode": "value",
        "wideLayout": true
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "last_over_time(last_ingestion_timestamp[1m])",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "Last Successful Ingestion Time",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisBorderShow": false,
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "barWidthFactor": 0.6,
            "drawStyle": "line",
            "fillOpacity": 25,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "insertNulls": false,
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "showValues": false,
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": 0
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        }
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 30
      },
      "id": 10,
      "options": {
        "annotations": {
          "clustering": -1,
          "multiLane": false
        },
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "hideZeros": false,
          "mode": "single",
          "sort": "none"
        }
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "avg_over_time(openf1_response_time_seconds[5m])",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "OpenF1 API Response Time",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prom-main"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "max": 22,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": 0
              },
              {
                "color": "red",
                "value": 0
              },
              {
                "color": "green",
                "value": 22
              }
            ]
          }
        }
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 30
      },
      "id": 11,
      "options": {
        "barShape": "flat",
        "barWidthFactor": 0.3,
        "effects": {
          "barGlow": false,
          "centerGlow": false,
          "gradient": true
        },
        "endpointMarker": "point",
        "minVizHeight": 75,
        "minVizWidth": 75,
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "segmentCount": 1,
        "segmentSpacing": 0.3,
        "shape": "gauge",
        "showThresholdLabels": false,
        "showThresholdMarkers": false,
        "sizing": "auto",
        "sparkline": true,
        "textMode": "auto"
      },
      "pluginVersion": "13.0.1+security-01",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prom-main"
          },
          "editorMode": "code",
          "expr": "active_drivers",
          "legendFormat": "__auto",
          "range": true,
          "refId": "A"
        }
      ],
      "title": "OpenF1 API Tracked Drivers",
      "type": "gauge"
    }
  ],
  "preload": false,
  "refresh": "",
  "schemaVersion": 42,
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "browser",
  "title": "F1 Telemetry System",
  "version": 23,
  "uid": "adncvfk",
  "id": 1802620253843456
}
EOF


echo "[+] Done creating Grafana dashboard JSON: F1 Telemetry System"

# -----------------------------
# Create monitoring compose file
# -----------------------------
echo "==========================================================="
echo "Creating monitoring docker compose file..."
echo "==========================================================="

cat <<EOF > monitoring/docker-compose.monitoring.yml
services:

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus

    ports:
      - "9090:9090"

    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml

    restart: unless-stopped

    networks:
      - telemetry-network


  grafana:
    image: grafana/grafana:latest
    container_name: grafana

    environment:
    - GF_INSTALL_PLUGINS=yesoreyeram-infinity-datasource
    - GF_AUTH_ANONYMOUS_ENABLED=true
    - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    - GF_DASHBOARDS_MIN_REFRESH_INTERVAL=5s

    ports:
      - "3000:3000"

    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/provisioning/dashboards-json:/var/lib/grafana/dashboards

    restart: unless-stopped

    networks:
      - telemetry-network


  loki:
    image: grafana/loki:latest
    container_name: loki

    ports:
      - "3100:3100"

    command: -config.file=/etc/loki/config.yml

    volumes:
      - ./loki/config.yml:/etc/loki/config.yml

    restart: unless-stopped

    networks:
      - telemetry-network


  promtail:
    image: grafana/promtail:latest
    container_name: promtail

    volumes:
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - ./promtail/config.yml:/etc/promtail/config.yml

    command: -config.file=/etc/promtail/config.yml

    networks:
      - telemetry-network


volumes:
  grafana-storage:

networks:
  telemetry-network:
    external: true
EOF

echo "[+] Done creating monitoring docker compose file."

# -----------------------------
# Start monitoring stack
# -----------------------------
echo "==========================================================="
echo "Starting monitoring containers..."
echo "==========================================================="

cd monitoring

docker compose -f docker-compose.monitoring.yml up -d

echo "[+] Monitoring containers started."

echo "==========================================================="
echo "Waiting for Grafana to be ready..."
echo "==========================================================="

until curl -s http://localhost:3000/api/health | grep -q "ok"; do
  sleep 2
done

echo "[+] Grafana is ready"



echo "=============================================================="
echo " Container Stack: "
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
echo "=========================================="
echo "Monitoring Stack:"
echo "=========================================="
echo "Current Containers Running:"
docker ps
echo ""
echo "=========================================="
echo "Access URLs"
echo "=========================================="
echo "Grafana:    curl http://localhost:3000"
echo "Prometheus: curl http://localhost:9090"
echo "Loki Ready: curl http://localhost:3100/ready"
echo "Loki Metrics: curl http://localhost:3100/metrics"
echo ""
echo "Prometheus Targets, use this command after a few minutes, systems should be up:"
echo "curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, state: .health}'"
echo ""
echo "Access Grafana in browser using External IP from the VM instance details page. Use http://<EXTERNAL_IP>:3000 to access Grafana."
echo "Access Prometheus in browser using http://<EXTERNAL_IP>:9090/targets to see the configured targets and their status."
echo ""
echo "Grafana Default Login:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo " To bring down the monitoring stack in the f1-telemetry directory, run: docker compose -f monitoring/docker-compose.monitoring.yml down -v"
echo ""

echo "==========================================================="
echo "Pushing FastAPI image to Artifact Registry..."
echo "==========================================================="

# Variables
REGION="australia-southeast1" # <-- REPLACE with your preferred region
REPO_NAME="pitwall-fastapi"
DESCRIPTION="F1 telemetry images"
SERVICE_ACCOUNT_ID="your-service-account-id" # <-- REPLACE with your actual service account ID (without the -)
SERVICE_ACCOUNT="${SERVICE_ACCOUNT_ID}-compute@developer.gserviceaccount.com"
ROLE="roles/artifactregistry.writer"

# Project ID for GCR
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
  echo "No GCP project set. Run: gcloud config set project <PROJECT_ID>"
  exit 1
fi

echo "Using project: $PROJECT_ID"
echo "Using region: $REGION"

# -----------------------------
# Enable required API
# -----------------------------
echo "Enabling Artifact Registry API..."
gcloud services enable artifactregistry.googleapis.com

# -----------------------------
# Create repository (ignore if exists)
# -----------------------------
echo "Creating Artifact Registry repo (if not exists)..."

gcloud artifacts repositories create "$REPO_NAME" \
  --repository-format=docker \
  --location="$REGION" \
  --description="$DESCRIPTION" \
  2>/dev/null || echo "Repository already exists, skipping."


# -----------------------------
# Grant Access to Compute Service Account (if needed)
# -----------------------------
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="$ROLE" \
  --quiet \
  2>&1 | grep -q "added" || echo "IAM binding already exists (or no change needed)"

# -----------------------------
# Output final registry path
# -----------------------------
echo ""
echo "Artifact Registry ready:"
echo "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"
echo ""


# Authenticate Docker to GCR

echo "Authenticating Docker to Google Container Registry..."
gcloud auth configure-docker "${REGION}-docker.pkg.dev" -q

# Docker Tag and Push Instructions
echo ""
echo "Tagging Docker image for GCR..."
docker tag "${DOCKER_IMAGE}" "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${DOCKER_IMAGE}"

echo "Pushing Docker image to Google Container Registry..."
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${DOCKER_IMAGE}"


echo "[+] FastAPI image pushed successfully to Artifact Registry"


echo "=========================================="
echo "SETUP COMPLETE"
echo "=========================================="