# Custom VPC (VPC-native cluster). Demonstrates networking ownership rather
# than leaning on the default network.
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.10.0.0/20"
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20"
  }
  private_ip_google_access = true
}

# --- Cloud NAT: ONLY needed if you enable private nodes in main.tf. ---
# Public nodes (the default here) reach the internet directly and need no NAT,
# which keeps the lab cheaper. Uncomment together with private_cluster_config.
# resource "google_compute_router" "router" {
#   name    = "${var.cluster_name}-router"
#   region  = var.region
#   network = google_compute_network.vpc.id
# }
# resource "google_compute_router_nat" "nat" {
#   name                               = "${var.cluster_name}-nat"
#   router                             = google_compute_router.router.name
#   region                             = var.region
#   nat_ip_allocate_option             = "AUTO_ONLY"
#   source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
# }
