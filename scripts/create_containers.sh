#!/bin/bash

# Create the f1-telemetry directory for files to be put in
mkdir -p f1-telemetry
cd f1-telemetry

# Create the files
touch  .env Dockerfile docker-compose.yml requirements.txt app/main.py

# Populate the files

# .env
cat <<EOL > POSTGRES_USER=postgres
POSTGRES_PASSWORD=changepasswordhere
POSTGRES_DB=f1_telemetry
DATABASE_URL=postgresql://postgres:changepasswordhere@db:5432/f1_telemetry
EOL

# Dockerfile
cat <<EOL > FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOL

# requirements.txt
cat <<EOL > fastapi
uvicorn[standard]
psycopg[binary]
EOL

# docker-compose.yml
cat <<EOL > services:
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

EOL

# Run the containers
docker-compose up -d --build

echo "Containers created and running. Access the FastAPI app at curl http://localhost:8000"
echo "To stop the containers, run: docker-compose down"
echo "To view logs, run: docker-compose logs -f"
echo "To access the database, run: docker exec -it postgres_db psql -U postgres -d f1_telemetry"
echo "Let's have a look at the running containers:"
docker ps