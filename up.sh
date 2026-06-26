#!/usr/bin/env bash
# up.sh — bring the GKE reference platform up with a single command.
# Stopgap that handles the WIF soft-delete 409 and the manual gcloud prep
# that aren't yet in Terraform. (The proper fix is moving these into TF +
# separating long-lived WIF state — planned refactor.)
#
# Usage:  ./up.sh
set -euo pipefail

# --- config -----------------------------------------------------------------
REGION="us-central1"
POOL="github-pool"
GH_PROVIDER="github-provider"
GL_PROVIDER="gitlab-provider"
AR_REPO="reference"
TF_DIR="$(cd "$(dirname "$0")/terraform" && pwd)"

cd "$TF_DIR"
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
echo ">> project: $PROJECT_ID ($PROJECT_NUMBER)"

# --- helper: undelete a WIF pool/provider if it's soft-deleted ---------------
ensure_pool_active() {
  local state
  state="$(gcloud iam workload-identity-pools describe "$POOL" \
            --location=global --format='value(state)' 2>/dev/null || echo MISSING)"
  if [[ "$state" == "DELETED" ]]; then
    echo ">> pool $POOL is soft-deleted; undeleting..."
    gcloud iam workload-identity-pools undelete "$POOL" --location=global
  else
    echo ">> pool $POOL state: $state"
  fi
}

ensure_provider_active() {
  local provider="$1" state
  state="$(gcloud iam workload-identity-pools providers describe "$provider" \
            --location=global --workload-identity-pool="$POOL" \
            --format='value(state)' 2>/dev/null || echo MISSING)"
  if [[ "$state" == "DELETED" ]]; then
    echo ">> provider $provider is soft-deleted; undeleting..."
    gcloud iam workload-identity-pools providers undelete "$provider" \
      --location=global --workload-identity-pool="$POOL"
  else
    echo ">> provider $provider state: $state"
  fi
}

# --- helper: import a resource into TF state only if not already tracked -----
tf_import_if_missing() {
  local addr="$1" id="$2"
  if terraform state list 2>/dev/null | grep -qxF "$addr"; then
    echo ">> $addr already in state, skipping import"
  else
    echo ">> importing $addr"
    terraform import "$addr" "$id" || echo "!! import of $addr failed (may not exist yet — apply will create it)"
  fi
}

# --- 1. make sure soft-deleted WIF resources are restored --------------------
ensure_pool_active
ensure_provider_active "$GH_PROVIDER"
ensure_provider_active "$GL_PROVIDER"

# --- 2. reconcile WIF resources into Terraform state -------------------------
# Only imports if the GCP object exists but TF isn't tracking it (the 409 case).
if gcloud iam workload-identity-pools describe "$POOL" --location=global >/dev/null 2>&1; then
  tf_import_if_missing google_iam_workload_identity_pool.github \
    "projects/${PROJECT_ID}/locations/global/workloadIdentityPools/${POOL}"
  tf_import_if_missing google_iam_workload_identity_pool_provider.github \
    "projects/${PROJECT_ID}/locations/global/workloadIdentityPools/${POOL}/providers/${GH_PROVIDER}"
  tf_import_if_missing google_iam_workload_identity_pool_provider.gitlab \
    "projects/${PROJECT_ID}/locations/global/workloadIdentityPools/${POOL}/providers/${GL_PROVIDER}"
fi

# --- 3. terraform apply ------------------------------------------------------
echo ">> terraform init + apply"
terraform init -input=false >/dev/null
terraform apply -auto-approve

# --- 4. manual gcloud prep not yet in Terraform ------------------------------
echo ">> ensuring Artifact Registry repo + node-SA pull binding"
gcloud artifacts repositories create "$AR_REPO" \
  --repository-format=docker --location="$REGION" \
  --description="reference platform images" 2>/dev/null || echo ">> AR repo exists"

gcloud artifacts repositories add-iam-policy-binding "$AR_REPO" \
  --location="$REGION" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/artifactregistry.reader" >/dev/null 2>&1 \
  && echo ">> node-SA pull binding ensured" || echo ">> binding exists"

# --- 5. connect kubectl ------------------------------------------------------
echo ">> fetching cluster credentials"
eval "$(terraform output -raw get_credentials)"

echo ""
echo ">> DONE. Cluster up, WIF reconciled, AR ready, kubectl connected."
echo ">> The GitLab/GitHub pipelines can now deploy."
