terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
  # Remote state with locking (GCS bucket). Create the bucket once, by hand or
  # in a bootstrap module, then uncomment.
  # backend "gcs" { bucket = "tfstate-<project>"  prefix = "gke-reference-platform" }
}
provider "google" {
  project = var.project_id
  region  = var.region
}
