import os
from fastapi import FastAPI
import psycopg

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
    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO telemetry (driver, lap_time)
        VALUES ('VER', 72.5);
    """)

    conn.commit()
    conn.close()

    return {"status": "data inserted"}


@app.get("/telemetry")
def get_telemetry():
    conn = psycopg.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("SELECT * FROM telemetry;")
    rows = cur.fetchall()

    conn.close()
    return {"data": rows}