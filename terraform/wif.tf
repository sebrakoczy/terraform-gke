# External Workload Identity Federation for GitHub Actions (keyless CI -> GCP).
locals {
  github_repo = "sebrakoczy/terraform-gke" # owner/repo
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == '${local.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "ci" {
  account_id   = "${var.cluster_name}-ci"
  display_name = "GitHub Actions CI"
}

resource "google_project_iam_member" "ci_artifactregistry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_service_account_iam_member" "ci_wif" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.github_repo}"
}

output "wif_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_account" {
  value = google_service_account.ci.email
}

# ---------------------------------------------------------------------------
# GitLab.com WIF provider (keyless GitLab CI -> GCP), on the same pool.
# Demonstrates the same OIDC federation pattern as GitHub, different issuer.
# ---------------------------------------------------------------------------
locals {
  gitlab_project_path = "sebrakoczy/terraform-gke"
}

resource "google_iam_workload_identity_pool_provider" "gitlab" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "gitlab-provider"
  display_name                       = "GitLab.com OIDC"

  attribute_mapping = {
    "google.subject"         = "assertion.sub"
    "attribute.project_path" = "assertion.project_path"
    "attribute.ref"          = "assertion.ref"
  }

  # Only this GitLab project may federate.
  attribute_condition = "assertion.project_path == '${local.gitlab_project_path}'"

  oidc {
    issuer_uri = "https://gitlab.com"
  }
}

# Let the GitLab project impersonate the CI service account.
resource "google_service_account_iam_member" "gitlab_ci_wif" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.project_path/${local.gitlab_project_path}"
}

output "gitlab_wif_provider" {
  value = google_iam_workload_identity_pool_provider.gitlab.name
}
