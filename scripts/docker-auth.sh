#!/bin/bash

# Google Container Registry (GCR) authentication script.
# This script authenticates Docker to GCR using the gcloud command-line tool.

# NOTE: Do NOT run this script on your local machine or the Cloud Shell. 
# It is meant to be run inside the Compute Engine VM where you want to push Docker images to GCR.

# Variables
REGION="australia-southeast1" # <-- REPLACE with your preferred region
REPO_NAME="f1-stack"
DOCKER_IMAGE="f1-telemetry-api:1.0"

# Project ID for GCR
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
  echo "No GCP project set. Run: gcloud config set project <PROJECT_ID>"
  exit 1
fi

# Authenticate Docker to GCR
echo "Authenticating Docker to Google Container Registry..."
gcloud auth configure-docker "${REGION}-docker.pkg.dev" -q

# Docker Tag and Push Instructions
echo ""
echo "Tagging Docker image for GCR..."
docker tag "${DOCKER_IMAGE}" "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${DOCKER_IMAGE}"

echo "Pushing Docker image to Google Container Registry..."
docker push "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${DOCKER_IMAGE}"

if [ $? -eq 0 ]; then
  echo "Docker image pushed successfully to GCR!"
else
  echo "Failed to push Docker image to GCR. Try the following solutions to fix the issue:"
  echo " In the IAM & Admin section of the GCP console, make sure that your compute service account has the 'Artifact Registry Reader' role for the project."
  echo "If you can't find the service account, it is usually in the format: <project-number>-compute@developer.gserviceaccount.com, you just need to grant access for it."
  echo " In your VM settings, stop the VM and then Allow full access to all Cloud APIs under the 'Access scopes' section. Restart the VM after making this change."
  exit 1
fi