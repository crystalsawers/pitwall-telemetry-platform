#!/bin/bash

# Script 2: Deploy Application to Kubernetes Cluster (Cloud Shell only)
# Generates and deploys all workloads from scratch

set -euo pipefail

# VARIABLES
K8S_DIR="k8s"
PROJECT_ID=$(gcloud config get-value project)
CLUSTER_NAME="f1-automated-cluster"
ZONE="australia-southeast1-a"

#-----------------------------------------
# PRE-DEPLOYMENT CHECKS
#-----------------------------------------
gcloud config set project $PROJECT_ID
echo "Project: $PROJECT_ID"
gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone "${ZONE}"

echo "Creating manifests directory..."
mkdir -p $K8S_DIR

# -----------------------------------------
# SECRET MANAGEMENT
# -----------------------------------------
echo "Checking Google Secret Manager secrets..."

MISSING=false

check_gsm_secret () {
  gcloud secrets describe "$1" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Missing Secret Manager secret: $1"
    MISSING=true
  fi
}

check_gsm_secret postgres-user
check_gsm_secret postgres-password
check_gsm_secret postgres-db

check_gsm_secret grafana-admin-user
check_gsm_secret grafana-admin-password

if [ "$MISSING" = true ]; then
  echo ""
  echo "One or more required Google Secret Manager secrets are missing."
  echo "Create them in Secret Manager before running this script."
  exit 1
fi

echo "All Secret Manager secrets exist. Proceeding..."

# -----------------------------------------
# Sync to Kubernetes secrets
# -----------------------------------------
echo "Syncing secrets from Secret Manager to Kubernetes..."

kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_USER="$(gcloud secrets versions access latest --secret=postgres-user)" \
  --from-literal=POSTGRES_PASSWORD="$(gcloud secrets versions access latest --secret=postgres-password)" \
  --from-literal=POSTGRES_DB="$(gcloud secrets versions access latest --secret=postgres-db)" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic grafana-secret \
  --from-literal=GF_SECURITY_ADMIN_USER="$(gcloud secrets versions access latest --secret=grafana-admin-user)" \
  --from-literal=GF_SECURITY_ADMIN_PASSWORD="$(gcloud secrets versions access latest --secret=grafana-admin-password)" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets synced successfully."

# -----------------------------------------
# DEPLOY WORKLOADS
# -----------------------------------------
echo "Deploying all workloads to Kubernetes cluster..."

# Deployment 1: PostgreSQL
echo "Deploying PostgreSQL..."
cat <<EOF > $K8S_DIR/postgres-db.yaml
apiVersion: "apps/v1"
kind: "Deployment"
metadata:
  name: "postgres-db"
  namespace: "default"
  labels:
    database: "postgres-db"
spec:
  replicas: 1
  selector:
    matchLabels:
      database: "postgres-db"
  template:
    metadata:
      labels:
        database: "postgres-db"
    spec:
      containers:
      - name: "postgres-1"
        image: "postgres:16"
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_USER

        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD

        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_DB
      nodeSelector:
        cloud.google.com/compute-class: "autopilot"
---
apiVersion: "autoscaling/v2"
kind: "HorizontalPodAutoscaler"
metadata:
  name: "postgres-db-hpa-mtok"
  namespace: "default"
  labels:
    database: "postgres-db"
spec:
  scaleTargetRef:
    kind: "Deployment"
    name: "postgres-db"
    apiVersion: "apps/v1"
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: "Resource"
    resource:
      name: "cpu"
      target:
        type: "Utilization"
        averageUtilization: 80
---
apiVersion: "v1"
kind: "Service"
metadata:
  name: "postgres-db-service"
  namespace: "default"
  labels:
    database: "postgres-db"
spec:
  ports:
  - protocol: "TCP"
    port: 5432
    targetPort: 5432
  selector:
    database: "postgres-db"
  type: "ClusterIP"
EOF

# Apply PostgreSQL deployment and schema setup
kubectl apply -f $K8S_DIR/postgres-db.yaml

echo "Waiting for Postgres to become ready..."

kubectl wait --for=condition=ready pod -l database=postgres-db --timeout=180s

# -----------------------------------------
# RUN POSTGRES INIT JOB (SCHEMA MIGRATION)
# -----------------------------------------
echo "Creating Postgres schema job..."

cat <<EOF > $K8S_DIR/postgres-init-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-init-schema
  namespace: default
spec:
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: init-schema
        image: postgres:16
        env:
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD
        command:
        - bash
        - -c
        - |
          echo "Waiting for Postgres..."
          until pg_isready -h postgres-db-service -p 5432; do
            sleep 2
          done

          echo "Creating schema..."
          psql -h postgres-db-service -U fastapi-postgres -d telemetry_db <<EOF_SQL
          CREATE TABLE IF NOT EXISTS telemetry (
              id SERIAL PRIMARY KEY,
              driver_number INT,
              driver_name TEXT,
              team_name TEXT,
              lap_number INT,
              lap_time DOUBLE PRECISION,
              position INT,
              data JSONB
          );
          EOF_SQL

          echo "Schema ready."
EOF

kubectl apply -f $K8S_DIR/postgres-init-job.yaml
kubectl wait --for=condition=complete job/postgres-init-schema --timeout=180s

echo "Postgres schema initialized."


# Deployment 2: FastAPI Application
echo "Deploying FastAPI application..."
cat <<EOF > $K8S_DIR/fastapi-app.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fastapi-app-config-yxwt
  namespace: default
  labels:
    app: fastapi-app
data:
  DB_HOST: "postgres-db-service"
  DB_PORT: "5432"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fastapi-app
  namespace: default
  labels:
    app: fastapi-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fastapi-app
  template:
    metadata:
      labels:
        app: fastapi-app
    spec:
      containers:
      - name: f1-telemetry-api-sha256-1
        image: australia-southeast1-docker.pkg.dev/project-1f40dd62-739c-473a-b20/f1-stack/f1-telemetry-api@sha256:dc951b017678db9c22071bcf294eed4b133f2d156e347b99a4d7cf5d643b5062
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_USER

        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_PASSWORD

        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: POSTGRES_DB

        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: fastapi-app-config-yxwt
              key: DB_HOST

        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: fastapi-app-config-yxwt
              key: DB_PORT

        - name: DATABASE_URL
          value: "postgresql://\$(POSTGRES_USER):\$(POSTGRES_PASSWORD)@\$(DB_HOST):\$(DB_PORT)/\$(POSTGRES_DB)"

      nodeSelector:
        cloud.google.com/compute-class: autopilot
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fastapi-app-hpa-hdmy
  namespace: default
  labels:
    app: fastapi-app
spec:
  scaleTargetRef:
    kind: Deployment
    name: fastapi-app
    apiVersion: apps/v1
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
---
apiVersion: v1
kind: Service
metadata:
  name: fastapi-app-service
  namespace: default
  labels:
    app: fastapi-app
spec:
  ports:
  - protocol: TCP
    port: 8000
    targetPort: 8000
  selector:
    app: fastapi-app
  type: LoadBalancer
EOF

# Deployment 3: Prometheus
echo "Deploying Prometheus..."
cat <<EOF > $K8S_DIR/prometheus.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: default
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ["localhost:9090"]

      - job_name: fastapi
        metrics_path: /metrics
        static_configs:
          - targets: ["fastapi-app-service:8000"]

        relabel_configs:
          - source_labels: [__address__]
            target_label: instance
          - target_label: job
            replacement: fastapi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: default
  labels:
    monitoring: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      monitoring: prometheus
  template:
    metadata:
      labels:
        monitoring: prometheus
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:latest
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
          ports:
            - containerPort: 9090

          resources:
            requests:
              cpu: 300m
              memory: 1Gi
            limits:
              cpu: 800m
              memory: 2Gi

          volumeMounts:
            - name: prometheus-config
              mountPath: /etc/prometheus/prometheus.yml
              subPath: prometheus.yml

      volumes:
        - name: prometheus-config
          configMap:
            name: prometheus-config

      nodeSelector:
        cloud.google.com/compute-class: autopilot

---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: default
spec:
  selector:
    monitoring: prometheus
  ports:
    - name: http
      port: 9090
      targetPort: 9090
  type: ClusterIP
EOF


# Deployment 4: Grafana
echo "Deploying Grafana..."
cat <<EOF > $K8S_DIR/grafana.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: default
data:
  datasources.yaml: |
    apiVersion: 1

    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
        editable: false
        
      - name: Infinity
        type: yesoreyeram-infinity-datasource
        access: proxy
        editable: false

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-provider
  namespace: default
data:
  provider.yaml: |
    apiVersion: 1

    providers:
      - name: "f1-dashboards"
        orgId: 1
        folder: "F1 Dashboards"
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-files
  namespace: default
data:

  f1-telemetry-data.json: |
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
          "type": "yesoreyeram-infinity-datasource"
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
              "type": "yesoreyeram-infinity-datasource"
            },
            "filters": [],
            "format": "table",
            "global_query_id": "",
            "parser": "backend",
            "refId": "A",
            "root_selector": "",
            "source": "url",
            "type": "json",
            "url": "http://fastapi-app-service:8000/session/info",
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
          
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
              "type": "prometheus"

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
          "type": "yesoreyeram-infinity-datasource"

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
              "type": "yesoreyeram-infinity-datasource"

            },
            "filters": [],
            "format": "table",
            "global_query_id": "",
            "parser": "backend",
            "refId": "A",
            "root_selector": "data",
            "source": "url",
            "type": "json",
            "url": "http://fastapi-app-service:8000/telemetry",
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
          "type": "yesoreyeram-infinity-datasource"
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
              "type": "yesoreyeram-infinity-datasource"
            },
            "filters": [],
            "format": "table",
            "global_query_id": "",
            "parser": "backend",
            "refId": "A",
            "root_selector": "data",
            "source": "url",
            "type": "json",
            "url": "http://fastapi-app-service:8000/championship/drivers",
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
          "type": "yesoreyeram-infinity-datasource"

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
              "type": "yesoreyeram-infinity-datasource"
            },
            "filters": [],
            "format": "table",
            "global_query_id": "",
            "parser": "backend",
            "refId": "A",
            "root_selector": "data",
            "source": "url",
            "type": "json",
            "url": "http://fastapi-app-service:8000/championship/constructors",
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

  f1-telemetry-system.json: |
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
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
                "options": "{instance=\"fastapi-app-service:8000\", job=\"fastapi\"}",
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
              "type": "prometheus"
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
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
              "type": "prometheus"
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
          "type": "prometheus"
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
              "type": "prometheus"
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
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: grafana
  namespace: default

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: default
  labels:
    monitoring: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      monitoring: grafana
  template:
    metadata:
      labels:
        monitoring: grafana
    spec:
      serviceAccountName: grafana
      automountServiceAccountToken: false

      containers:
      - name: grafana
        image: grafana/grafana
        ports:
        - containerPort: 3000

        env:
        - name: GF_SECURITY_ADMIN_USER
          valueFrom:
            secretKeyRef:
              name: grafana-secret
              key: GF_SECURITY_ADMIN_USER

        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secret
              key: GF_SECURITY_ADMIN_PASSWORD

        - name: GF_INSTALL_PLUGINS
          value: yesoreyeram-infinity-datasource

        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 300m
            memory: 256Mi

        volumeMounts:
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources

        - name: grafana-dashboards
          mountPath: /var/lib/grafana/dashboards

        - name: grafana-dashboard-provider
          mountPath: /etc/grafana/provisioning/dashboards

      volumes:
      - name: grafana-datasources
        configMap:
          name: grafana-datasources

      - name: grafana-dashboards
        configMap:
          name: grafana-dashboard-files

      - name: grafana-dashboard-provider
        configMap:
          name: grafana-dashboard-provider

      nodeSelector:
        cloud.google.com/compute-class: autopilot
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: default
  labels:
    monitoring: grafana
spec:
  selector:
    monitoring: grafana
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
  type: LoadBalancer
EOF

# -------------------------------------------
# APPLY ALL MANIFESTS
# -------------------------------------------

kubectl apply -f $K8S_DIR

echo "All workloads deployed successfully."

echo "Waiting for deployments..."
echo ""
echo "Pods:"
kubectl get pods
echo ""
echo "Services:"
kubectl get svc
echo ""
echo "NOTE: Pods may initially show as Pending or ContainerCreating while nodes are provisioning and images are pulling."
echo "Give it a couple of minutes and run 'kubectl get pods && kubectl get svc' again to check the status of your workloads."