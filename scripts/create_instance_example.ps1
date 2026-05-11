# POWERSHELL VERSION OF create_instance_example.sh

# Setup Google Cloud CLI Install if not already installed

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "gcloud not found. Installing Google Cloud CLI..."

    # Install via winget (recommended on Windows)
    winget install -e --id Google.CloudSDK
}

# Authenticate Google Cloud CLI if not already authenticated.
#
# INTERACTIVE MODE (default for local machines):
# - Uses browser login via:
#   gcloud auth login
#
# NON-INTERACTIVE MODE (servers / no browser / automation):
# - Requires a Service Account JSON key file
# - To create it:
#   1. Go to Google Cloud Console
#   2. IAM & Admin → Service Accounts
#   3. Select or create a service account
#   4. Go to "Keys" tab
#   5. Click "Add Key" → "Create new key"
#   6. Choose JSON → download file
#   7. Place it locally (e.g. ./service-account.json)
#
# Then replace this block with:
#   gcloud auth activate-service-account --key-file=./service-account.json

$activeAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)"

if (-not $activeAccount) {
    Write-Host "No active gcloud authentication detected. Starting login..."
    gcloud auth login
}

# Create Google Cloud Compute Engine instance for Pitwall Telemetry Platform

# Set variables (replace placeholders before running)
$PROJECT_ID = "your-project-id"
$ZONE = "your-zone"  # e.g. australia-southeast1-c
$REGION = $ZONE -replace "-[a-z]$",""
$INSTANCE_NAME = "your-instance-name"
$MACHINE_TYPE = "machine-type" # e.g. e2-standard-2

$IMAGE_PROJECT = "your-image-project"
$IMAGE_NAME = "your-image-name"

$DISK_SIZE = "30GB"
$DISK_TYPE = "pd-balanced"

$NETWORK = "default"
$SERVICE_ACCOUNT = "your-service-account@your-project.iam.gserviceaccount.com"

$SCOPES = "https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append"

gcloud config set project $PROJECT_ID

# Create the instance
gcloud compute instances create $INSTANCE_NAME `
    --project=$PROJECT_ID `
    --zone=$ZONE `
    --description="Automated version" `
    --machine-type=$MACHINE_TYPE `
    --network-interface="network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=$NETWORK" `
    --maintenance-policy=MIGRATE `
    --provisioning-model=STANDARD `
    --service-account=$SERVICE_ACCOUNT `
    --scopes=$SCOPES `
    --tags="http-server,https-server" `
    --create-disk="auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,disk-resource-policy=projects/$PROJECT_ID/regions/$REGION/resourcePolicies/default-schedule-1,image=projects/$IMAGE_PROJECT/global/images/$IMAGE_NAME,mode=rw,size=$DISK_SIZE,type=$DISK_TYPE" `
    --no-shielded-secure-boot `
    --shielded-vtpm `
    --shielded-integrity-monitoring `
    --labels=goog-ec-src=vm_add-gcloud `
    --reservation-affinity=any