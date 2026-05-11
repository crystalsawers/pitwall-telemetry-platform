#!/bin/bash

# For the VM you NEED to run as root, otherwise this wont work
if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo: sudo $0"
  echo "Use 'sudo -i' to get a root shell and then run the script. You will get 'root@pitwall-vm:~# '"
  echo "If you're uploading the script, move it to the root user's home directory: mv ~/create_containers.sh /root/."
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
POSTGRES_PASSWORD=changepasswordhere
POSTGRES_DB=f1_telemetry
DATABASE_URL=postgresql://postgres:changepasswordhere@db:5432/f1_telemetry
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
EOF

# app/main.py
cat <<EOF > app/main.py
import os
from fastapi import FastAPI
import psycopg
import requests

app = FastAPI()

DATABASE_URL = os.getenv("DATABASE_URL")


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


@app.post("/telemetry/init")
def init_table():
    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS telemetry (
            id SERIAL PRIMARY KEY,
            driver TEXT,
            lap_time FLOAT
        );
    """)

    conn.commit()
    conn.close()

    return {"status": "table created"}


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
        driver = str(lap.get("driver_number", "UNK"))
        lap_time = lap.get("lap_duration")

        if lap_time is not None:
            cur.execute("""
                INSERT INTO telemetry (driver, lap_time)
                VALUES (%s, %s);
            """, (driver, lap_time))

            inserted += 1

    conn.commit()
    conn.close()

    return {"status": f"{inserted} rows inserted"}


@app.get("/telemetry")
def get_telemetry():
    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("SELECT * FROM telemetry;")
    rows = cur.fetchall()

    conn.close()
    return {"data": rows}
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

volumes:
  pgdata:
EOF

# Run the containers
docker compose up -d --build

echo "Containers created and running. Access the FastAPI app at curl http://localhost:8000"
echo "Also test the following: curl -X POST http://localhost:8000/telemetry/init ,  curl -X POST http://localhost:8000/telemetry/add , curl http://localhost:8000/telemetry"
echo "To stop the containers, run: cd f1-telemetry && docker compose down"
echo "To view logs, run: cd f1-telemetry && docker compose logs -f"
echo "To access the database, run: cd f1-telemetry && docker exec -it postgres_db psql -U postgres -d f1_telemetry"
echo "Let's have a look at the running containers:"
docker ps