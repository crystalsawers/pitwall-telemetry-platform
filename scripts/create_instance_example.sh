#!/bin/bash

# Create Google Cloud Compute Engine instance for Pitwall Telemetry Platform

# Set variables (replace placeholders before running)
PROJECT_ID="your-project-id"
ZONE="your-zone"  # e.g. australia-southeast1-c
REGION="${ZONE%-*}"
INSTANCE_NAME="your-instance-name"
MACHINE_TYPE="machine-type" # e.g. e2-standard-2, e2-highmem-2, etc.
IMAGE_PROJECT="your-image-project"
IMAGE_NAME="your-image-name"
DISK_SIZE="30GB" # change if you need a different disk size
DISK_TYPE="pd-balanced"
NETWORK="default"
SERVICE_ACCOUNT="your-service-account@your-project.iam.gserviceaccount.com"
SCOPES="https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append"

# Create the instance
gcloud compute instances create $INSTANCE_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --description="Automated version" \
    --machine-type=$MACHINE_TYPE \
    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=$NETWORK \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=$SERVICE_ACCOUNT \
    --scopes=$SCOPES \
    --tags=http-server,https-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,disk-resource-policy=projects/$PROJECT_ID/regions/$REGION/resourcePolicies/default-schedule-1,image=projects/$IMAGE_PROJECT/global/images/$IMAGE_NAME,mode=rw,size=$DISK_SIZE,type=$DISK_TYPE \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any