resource "google_container_cluster" "this" {
  name             = var.cluster_name
  location         = var.region
  enable_autopilot = true

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  release_channel { channel = "REGULAR" }

  # Workload Identity is enabled by default on Autopilot; declared for clarity.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # GKE-managed Secret Manager add-on (CSI), used by the Phase 4 secrets work.
  secret_manager_config { enabled = true }

  # Lab: provider defaults this to true, which blocks `terraform destroy`.
  deletion_protection = false

  # --- production hardening (uncomment; private nodes require Cloud NAT) ---
  # private_cluster_config {
  #   enable_private_nodes    = true
  #   enable_private_endpoint = false
  #   master_ipv4_cidr_block  = "172.16.0.0/28"
  # }
}
