resource "google_service_account" "app" {
  account_id   = "${var.cluster_name}-app"
  display_name = "Reference app workload identity"
}

resource "google_project_iam_member" "app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.app_namespace}/${var.app_ksa}]"
  depends_on         = [google_container_cluster.this]
}
