from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"status": "F1 telemetry API running"}