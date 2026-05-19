#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo: sudo $0"
  echo "Use 'sudo -i' to get a root shell and then run the script. You will get 'root@pitwall-vm:~# '"
  echo "If you're uploading the script, move it to the root user's home directory: mv ~/basic_setup.sh /root/."
  echo "Use chmod +x basic_setup.sh to make it executable, then run it with sudo: ./basic_setup.sh"
  exit 1
fi

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
echo "[+] Creating monitoring directories..."

mkdir -p monitoring/{prometheus,grafana/provisioning,loki,promtail}


# -----------------------------
# Create Prometheus config
# -----------------------------
echo "[+] Creating Prometheus configuration..."

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


# -----------------------------
# Create Loki config
# -----------------------------
echo "[+] Creating Loki configuration..."

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


# -----------------------------
# Create Promtail config
# -----------------------------
echo "[+] Creating Promtail configuration..."

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


# -----------------------------
# Create monitoring compose file
# -----------------------------
echo "[+] Creating monitoring docker compose file..."

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


# -----------------------------
# Create Docker network
# -----------------------------
echo "[+] Creating Docker network if missing..."

docker network inspect telemetry-network >/dev/null 2>&1 || \
docker network create telemetry-network


# -----------------------------
# Start monitoring stack
# -----------------------------
echo "[+] Starting monitoring containers..."

cd monitoring

docker compose -f docker-compose.monitoring.yml up -d


# -----------------------------
# Status output
# -----------------------------
echo ""
echo "=========================================="
echo "Monitoring Stack Started"
echo "=========================================="

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
echo "Promtail Logs (last 10 lines):"
docker logs promtail --tail 10

echo ""
echo "Prometheus Targets:"
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, state: .health}'

echo ""
echo "Access Grafana in browser using External IP from the VM instance details page. Use http://<EXTERNAL_IP>:3000 to access Grafana."
echo "Access Prometheus in browser using http://<EXTERNAL_IP>:9090/targets to see the configured targets and their status."

echo ""
echo "Grafana Default Login:"
echo "  Username: admin"
echo "  Password: admin"

echo ""
echo "Setup complete."