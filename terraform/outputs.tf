output "get_credentials" {
  value = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
}
output "app_gsa_email" {
  value = google_service_account.app.email
}
output "annotate_ksa" {
  description = "Run after creating the KSA so the pod assumes the Google SA."
  value       = "kubectl annotate sa ${var.app_ksa} -n ${var.app_namespace} iam.gke.io/gcp-service-account=${google_service_account.app.email}"
}
