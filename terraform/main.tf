# Cost note: GKE Autopilot bills per running pod and has no node-management
# overhead, which makes it the cheapest "real" target for an ephemeral lab.
# Spin up -> demo -> `terraform destroy`.

resource "google_container_cluster" "this" {
  name                = var.cluster_name
  location            = var.region
  enable_autopilot    = true            # managed nodes, secure defaults, scale-to-zero-ish
  deletion_protection = false           # lab: allow clean teardown

  # Workload Identity Federation: pods assume GCP service accounts via OIDC,
  # eliminating static service-account keys (the IRSA equivalent).
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

output "cluster_endpoint" { value = google_container_cluster.this.endpoint  sensitive = true }
output "get_credentials" {
  value = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
}
