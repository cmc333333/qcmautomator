terraform {
  backend "local" {}

  required_providers {
    google = "~> 5.9.0"
  }
}

provider "google" {
  project = "qcmautomator"
}

resource "google_project" "qcmautomator" {
  name       = "Quantified CM Automator"
  project_id = "qcmautomator"
}

resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
}

resource "google_service_account" "deployer" {
  account_id = "deployer"
  project    = google_project_service.iam.project
}

resource "google_service_account_iam_binding" "deployer_impersonators" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.serviceAccountTokenCreator"
  members            = ["user:cmc333333@gmail.com"]
}

resource "google_project_iam_member" "deployer" {
  project = google_project.qcmautomator.project_id
  role    = "roles/owner"
  member  = google_service_account.deployer.member
}

resource "google_project_service" "storage" {
  service = "storage.googleapis.com"
}

resource "google_storage_bucket" "deployment_state" {
  project                     = google_project_service.storage.project
  name                        = "qcmautomator-deployment-state"
  location                    = "US"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  # Delete old versions after a year
  lifecycle_rule {
    condition {
      age        = 365
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}
