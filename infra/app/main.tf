terraform {
  backend "gcs" {
    # bucket provided at init time
    prefix = "app"
  }
  required_providers {
    google = "~> 3.51.1"
  }
}

provider "google" {
  project = replace(var.deploy_gcp_project_id, "-deploy", "")
  zone    = "us-central1-c"
}

data "google_project" "project" {}
