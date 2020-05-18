variable "gcp_project_id" {
  type = string
}
variable "app_name" {
  type = string
}

terraform {
  backend "gcs" {}
}

provider "google" {
  project = var.gcp_project_id
}

resource "google_cloud_run_service" "app" {
  name     = var.app_name
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/${var.gcp_project_id}/${var.app_name}"
      }
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

output "service_url" {
  value = google_cloud_run_service.app.status[0].url
}
