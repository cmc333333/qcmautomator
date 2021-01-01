terraform {
  backend "gcs" {
    # bucket and impersonation provided at init time
  }
  required_providers {
    google = "~> 3.51.0"
  }
}

provider "google" {
  project                     = var.gcp_project_id
  impersonate_service_account = var.deployer_account
  zone                        = "us-central1-c"
}

data "google_project" "project" {
  project_id          = var.gcp_project_id
}

resource "google_logging_project_bucket_config" "extend-retention" {
  project        = var.gcp_project_id
  location       = "global"
  retention_days = 3650
  bucket_id      = "_Default"
}
