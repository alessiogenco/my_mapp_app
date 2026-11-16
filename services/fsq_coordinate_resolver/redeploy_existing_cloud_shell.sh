#!/usr/bin/env bash
# Rebuilds the existing Cloud Run resolver without changing its two secrets.
# Run this from the uploaded resolver folder in Google Cloud Shell.

set -euo pipefail

PROJECT_ID="${1:-my-map-app-495216}"
REGION="${2:-europe-north1}"
SERVICE_NAME="my-locals-fsq-resolver"
SERVICE_ACCOUNT_EMAIL="my-locals-fsq-resolver@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud config set project "${PROJECT_ID}"

gcloud run deploy "${SERVICE_NAME}" \
  --source . \
  --region="${REGION}" \
  --allow-unauthenticated \
  --service-account="${SERVICE_ACCOUNT_EMAIL}" \
  --set-secrets="FSQ_OS_PLACES_TOKEN=FSQ_OS_PLACES_TOKEN:latest,RESOLVER_SHARED_SECRET=MY_LOCALS_FSQ_RESOLVER_KEY:latest" \
  --memory="2Gi" \
  --cpu="1" \
  --min-instances="0" \
  --concurrency="1" \
  --max-instances="1" \
  --timeout="120"

echo "Resolver redeployed. The service URL and resolver key are unchanged."
