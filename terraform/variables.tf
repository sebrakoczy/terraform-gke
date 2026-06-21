variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1" # Autopilot is regional
}

variable "cluster_name" {
  type    = string
  default = "reference-platform"
}

variable "app_namespace" {
  type    = string
  default = "production"
}

variable "app_ksa" {
  type    = string
  default = "reference-app" # Kubernetes SA name
}
