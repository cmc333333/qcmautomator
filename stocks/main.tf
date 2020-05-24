variable "gcp_project_id" {
  type = string
}
variable "app_name" {
  type = string
}
variable "image_digest" {
  type = string
}

terraform {
  backend "gcs" {}
  required_providers {
    google      = "~> 3.22"
    google-beta = "~> 3.22"
  }
}

provider "google" {
  project = var.gcp_project_id
}

provider "google-beta" {
  project = var.gcp_project_id
}

resource "google_project_service" "iam" {
  service                    = "iam.googleapis.com"
  disable_dependent_services = true
}

resource "google_service_account" "runner" {
  account_id = var.app_name

  depends_on = [google_project_service.iam]
}

resource "google_cloud_run_service" "app" {
  name     = var.app_name
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/${var.gcp_project_id}/${var.app_name}@${var.image_digest}"
        env {
          name  = "GCP_PROJECT_ID"
          value = var.gcp_project_id
        }
        env {
          name  = "APP_NAME"
          value = var.app_name
        }
      }
      service_account_name = google_service_account.runner.email
    }
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.app.location
  project     = google_cloud_run_service.app.project
  service     = google_cloud_run_service.app.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_cloud_scheduler_job" "job" {
  name             = "test-job"
  region           = "us-central1"
  schedule         = "*/20 * * * *"
  time_zone        = "America/New_York"

  http_target {
    http_method = "GET"
    uri         = google_cloud_run_service.app.status[0].url
  }
}

resource "google_secret_manager_secret_iam_binding" "access" {
  provider  = google-beta
  secret_id = var.app_name
  role      = "roles/secretmanager.secretAccessor"
  members   = ["serviceAccount:${google_service_account.runner.email}"]
}

output "service_url" {
  value = google_cloud_run_service.app.status[0].url
}
