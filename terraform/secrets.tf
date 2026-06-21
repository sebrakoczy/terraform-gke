# Create the secret container in Terraform, but NOT its value — adding the value
# here would store it in Terraform state. The runbook adds the version via gcloud.
resource "google_secret_manager_secret" "app_api_key" {
  secret_id = "reference-app-api-key"
  replication {
    auto {}
  }
}

# Scoped least-privilege: only this secret, only the app's Google SA. With this,
# you can drop the broad project-level secretAccessor grant in iam.tf.
resource "google_secret_manager_secret_iam_member" "app_access" {
  secret_id = google_secret_manager_secret.app_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}
