terraform {
  backend "gcs" {
    # bucket is provided at init time
    prefix = "qcmautomator-bootstrap.tfstate"
  }
  required_providers {
    google = "~> 3.51.0"
  }
}

provider "google" {
  project = var.gcp_project_id
}

resource "google_project" "project" {
  name                = "Quantified CM Automator"
  project_id          = var.gcp_project_id
  auto_create_network = false
  billing_account     = var.gcp_billing_account
}

resource "google_service_account" "deployer" {
  account_id = "deployer"
}

resource "google_storage_bucket" "deploy-state" {
  name                        = "${var.gcp_project_id}-deploy-state"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_binding" "deploy-state" {
  bucket  = google_storage_bucket.deploy-state.name
  role    = "roles/storage.objectAdmin"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

resource "google_service_account_iam_binding" "deployer-token-creator" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.serviceAccountTokenCreator"
  members            = [
    "serviceAccount:${google_project.project.number}@cloudbuild.gserviceaccount.com",
    # self
    "serviceAccount:${google_service_account.deployer.email}"
  ]
}

resource "google_service_account_iam_binding" "deployer-act-as" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.serviceAccountUser"
  members            = [
    "serviceAccount:${google_project.project.number}@cloudbuild.gserviceaccount.com",
    # self
    "serviceAccount:${google_service_account.deployer.email}"
  ]
}

resource "google_project_service" "bigquery" {
  service = "bigquery.googleapis.com"
}

resource "google_project_service" "build" {
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
}

resource "google_project_service" "kms" {
  service = "cloudkms.googleapis.com"
}

resource "google_project_service" "logging" {
  service = "logging.googleapis.com"
}

resource "google_project_service" "scheduler" {
  service = "cloudscheduler.googleapis.com"
}

resource "google_project_service" "storage" {
  service = "storage-component.googleapis.com"
}

resource "google_project_iam_binding" "deployer-bigquery" {
  role    = "roles/bigquery.admin"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

resource "google_project_iam_binding" "deployer-build" {
  role    = "roles/cloudbuild.builds.builder"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

resource "google_project_iam_binding" "deployer-iam" {
  role    = "roles/iam.serviceAccountAdmin"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

resource "google_project_iam_binding" "deployer-kms" {
  role    = "roles/cloudkms.admin"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

resource "google_project_iam_binding" "deployer-logging" {
  role    = "roles/logging.admin"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

resource "google_project_iam_binding" "deployer-scheduler" {
  role    = "roles/cloudscheduler.admin"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

resource "google_project_iam_binding" "deployer-storage" {
  role    = "roles/storage.admin"
  members = ["serviceAccount:${google_service_account.deployer.email}"]
}

resource "google_project_iam_member" "books-can-write-logs" {
  role   = "roles/logging.logWriter"
  member = "serviceAccount:books-executor@${var.gcp_project_id}.iam.gserviceaccount.com"
}
