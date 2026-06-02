#!/bin/bash

set -euo pipefail

echo "GKE / Kubernetes cleanup starting..."


# VARIABLES

PROJECT_ID=$(gcloud config get-value project)
REGION="australia-southeast1"
ZONE="australia-southeast1-a"
CLUSTER_NAME="f1-automated-cluster"
K8S_DIR="k8s"

echo "Project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# ---------------------------------------
# Connect to cluster (if available)
# ---------------------------------------
echo "Checking cluster connection..."

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone "$ZONE" >/dev/null 2>&1 || \
  echo "Cluster not accessible (may already be deleted)"

# ---------------------------------------
# Delete Kubernetes manifests
# ---------------------------------------
if [ -d "$K8S_DIR" ]; then
  echo "Deleting manifests from $K8S_DIR"
  kubectl delete -f "$K8S_DIR" --ignore-not-found=true || true
fi

# ---------------------------------------
# Clean in-cluster resources
# ---------------------------------------
echo "Cleaning Kubernetes resources..."

kubectl delete all --all --all-namespaces --ignore-not-found=true || true
kubectl delete ingress --all --all-namespaces --ignore-not-found=true || true
kubectl delete configmap --all --all-namespaces --ignore-not-found=true || true
kubectl delete secret --all --all-namespaces --ignore-not-found=true || true
kubectl delete pvc --all --all-namespaces --ignore-not-found=true || true
kubectl delete svc --all --all-namespaces --ignore-not-found=true || true

# ---------------------------------------
# Delete cluster
# ---------------------------------------
echo "Deleting cluster: $CLUSTER_NAME"

gcloud container clusters delete "$CLUSTER_NAME" \
  --zone "$ZONE" \
  --quiet || echo "Cluster not found"

# ---------------------------------------
# Cleanup load balancer leftovers
# ---------------------------------------
echo "Cleaning load balancer resources..."

gcloud compute forwarding-rules list \
  --format="value(name,region)" | while read name region; do
    [ -z "$name" ] && continue
    gcloud compute forwarding-rules delete "$name" --region="$region" --quiet || true
done

gcloud compute target-http-proxies list --format="value(name)" | while read name; do
    [ -z "$name" ] && continue
    gcloud compute target-http-proxies delete "$name" --quiet || true
done

gcloud compute target-https-proxies list --format="value(name)" | while read name; do
    [ -z "$name" ] && continue
    gcloud compute target-https-proxies delete "$name" --quiet || true
done


echo "Cleanup complete"