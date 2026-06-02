#!/bin/bash

# Script 3: This is extra config for AFTER deployments

#----------------------------------------
# SERVICES
#-----------------------------------------

# Loki Service (needed for Promtail DNS)
echo "Applying Loki Service..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: loki-logs
  namespace: default
spec:
  selector:
    monitoring: loki-logs
  ports:
    - name: http
      port: 3100
      targetPort: 3100
  type: ClusterIP
EOF


# Prometheus Service
echo "Applying Prometheus Service..."

cat <<EOF | kubectl apply -f -
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
EOF


echo "Services applied"

echo "Verifying service + endpoints..."

kubectl get svc loki-logs
kubectl get endpoints loki-logs
kubectl get svc prometheus
kubectl get endpoints prometheus

# RESTARTS
kubectl rollout restart deploy/promtail
kubectl rollout status deploy/promtail

