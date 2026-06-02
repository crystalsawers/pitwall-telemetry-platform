#!/bin/bash

# Script 1: Create Kubernetes Cluster on GKE

# VARIABLES
PROJECT_ID=$(gcloud config get-value project)

CLUSTER_NAME="f1-automated-cluster"

REGION="australia-southeast1"
ZONE="australia-southeast1-a"

MACHINE_TYPE="e2-medium"
DISK_SIZE="30"
NUM_NODES="3"


# Create Cluster
gcloud beta container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --no-enable-basic-auth \
    --cluster-version="1.35.3-gke.1389002" \
    --release-channel="regular" \
    --machine-type=$MACHINE_TYPE \
    --image-type="COS_CONTAINERD" \
    --disk-type="pd-standard" \
    --disk-size=$DISK_SIZE \
    --metadata=disable-legacy-endpoints=true \
    --num-nodes=$NUM_NODES \
    --logging=SYSTEM,WORKLOAD \
    --monitoring=SYSTEM,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA,JOBSET,CADVISOR,KUBELET,DCGM \
    --enable-ip-alias \
    --network="default" \
    --subnetwork="default" \
    --cluster-ipv4-cidr="/17" \
    --no-enable-intra-node-visibility \
    --default-max-pods-per-node="110" \
    --enable-autoscaling \
    --min-nodes="0" \
    --max-nodes="6" \
    --location-policy="BALANCED" \
    --security-posture=standard \
    --workload-vulnerability-scanning=disabled \
    --addons=HorizontalPodAutoscaling,HttpLoadBalancing,NodeLocalDNS,GcePersistentDiskCsiDriver \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade=1 \
    --max-unavailable-upgrade=0 \
    --binauthz-evaluation-mode=DISABLED \
    --enable-managed-prometheus \
    --enable-shielded-nodes \
    --shielded-integrity-monitoring \
    --no-shielded-secure-boot \
    --node-locations=$ZONE

# Stop script if cluster creation failed
if [ $? -ne 0 ]; then
    echo "Cluster creation failed."
    exit 1
fi

# Fetch cluster credentials
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID

# Verify cluster
kubectl get nodes
kubectl get pods -A