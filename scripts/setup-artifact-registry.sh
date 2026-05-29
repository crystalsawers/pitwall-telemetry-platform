#!/bin/bash

# Google Artifact Registry setup script, works on local machine or in the Google Cloud Shell. 
# This script sets up an Artifact Registry repository for Docker images and grants necessary permissions to the Compute Engine service account.

# -----------------------------
# Config (edit if needed)
# -----------------------------
REGION="australia-southeast1" # <-- REPLACE with your preferred region (must be the same as your VM region for best performance, but can be different if needed)
REPO_NAME="f1-stack"
DESCRIPTION="F1 telemetry images"
SERVICE_ACCOUNT_ID="your-service-account-id" # <-- REPLACE with your actual service account ID (without the -)
SERVICE_ACCOUNT="${SERVICE_ACCOUNT_ID}-compute@developer.gserviceaccount.com"
ROLE="roles/artifactregistry.writer"

# -----------------------------
# Get current GCP project
# -----------------------------
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
  echo "No GCP project set. Run: gcloud config set project <PROJECT_ID>"
  exit 1
fi

echo "Using project: $PROJECT_ID"
echo "Using region: $REGION"

# -----------------------------
# Enable required API
# -----------------------------
echo "Enabling Artifact Registry API..."
gcloud services enable artifactregistry.googleapis.com

# -----------------------------
# Create repository (ignore if exists)
# -----------------------------
echo "Creating Artifact Registry repo (if not exists)..."

gcloud artifacts repositories create "$REPO_NAME" \
  --repository-format=docker \
  --location="$REGION" \
  --description="$DESCRIPTION" \
  2>/dev/null || echo "Repository already exists, skipping."


# -----------------------------
# Grant Access to Compute Service Account (if needed)
# -----------------------------
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="$ROLE" \
  --quiet \
  2>&1 | grep -q "added" || echo "IAM binding already exists (or no change needed)"

# -----------------------------
# Output final registry path
# -----------------------------
echo ""
echo "Artifact Registry ready:"
echo "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"
echo ""
echo "Next step: docker tag + docker push for f1-telemetry-api. Upload and Run the docker-auth.sh script inside your VM to do this."