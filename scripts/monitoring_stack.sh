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
echo " To bring down the monitoring stack, run: docker compose -f monitoring/docker-compose.monitoring.yml down -v"

echo ""
echo "Setup complete."