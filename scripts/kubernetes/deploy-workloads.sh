#!/bin/bash

# Script 2: Deploy Application to Kubernetes Cluster (Cloud Shell only)
# Generates and deploys all workloads from scratch

set -euo pipefail

# VARIABLES
K8S_DIR="k8s" # This is the folder all Kubernetes manifests will be generated
PROJECT_ID=$(gcloud config get-value project)

gcloud config set project $PROJECT_ID
gcloud container clusters get-credentials f1-automated-cluster --zone australia-southeast1-a

echo "Creating manifests directory..."
mkdir -p $K8S_DIR

# Workload Deployment code in progress...