#!/usr/bin/env bash
# Deploys the private-coordinate resolver from Google Cloud Shell.
# It asks for the Foursquare token without echoing it and stores both secrets
# in Google Secret Manager. Neither is written into the source folder.

set -euo pipefail

PROJECT_ID="${1:-my-map-app-495216}"
REGION="${2:-europe-north1}"
SERVICE_NAME="my-locals-fsq-resolver"
SERVICE_ACCOUNT_NAME="my-locals-fsq-resolver"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud config set project "${PROJECT_ID}"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com

if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT_EMAIL}" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
    --display-name="My Locals Foursquare coordinate resolver"
fi

add_secret_version() {
  local secret_name="$1"
  local value="$2"

  if ! gcloud secrets describe "${secret_name}" >/dev/null 2>&1; then
    gcloud secrets create "${secret_name}" --replication-policy="automatic"
  fi

  printf '%s' "${value}" | gcloud secrets versions add "${secret_name}" --data-file=-
  gcloud secrets add-iam-policy-binding "${secret_name}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/secretmanager.secretAccessor" >/dev/null
}

read -r -s -p "Paste the Foursquare OS Places token, then press Enter: " FSQ_TOKEN
echo
if [[ -z "${FSQ_TOKEN}" ]]; then
  echo "No Foursquare token was supplied." >&2
  exit 1
fi

# The same value will later be entered once into Supabase. It ensures that
# only My Locals' Edge Function can call this publicly reachable Cloud Run URL.
RESOLVER_SHARED_SECRET="$(openssl rand -hex 32)"

add_secret_version "FSQ_OS_PLACES_TOKEN" "${FSQ_TOKEN}"
add_secret_version "MY_LOCALS_FSQ_RESOLVER_KEY" "${RESOLVER_SHARED_SECRET}"
unset FSQ_TOKEN

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

SERVICE_URL="$(gcloud run services describe "${SERVICE_NAME}" --region="${REGION}" --format='value(status.url)')"

echo
echo "Deployment complete. Service URL: ${SERVICE_URL}"
echo "Copy this resolver key now; it is shown only here and is needed once for Supabase:"
echo "${RESOLVER_SHARED_SECRET}"
unset RESOLVER_SHARED_SECRET
