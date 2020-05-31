variable "gcp_project_id" {
  type = string
}
variable "app_name" {
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

resource "google_cloud_scheduler_job" "run" {
  name      = "run-${var.app_name}"
  region    = "us-central1"
  schedule  = "30 * * * *"
  time_zone = "America/New_York"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${var.gcp_project_id}/builds"
    body        = base64encode(jsonencode(yamldecode(<<-EOF
      tags: ["run", "${var.app_name}"]
      steps:
      - name: gcr.io/cloud-builders/gcloud
        args:
        - iam
        - service-accounts
        - keys
        - create
        - creds.json
        - --iam-account=${google_service_account.runner.email}
      - name: gcr.io/${var.gcp_project_id}/${var.app_name}
        env:
        - GCP_PROJECT_ID=${var.gcp_project_id}
        - APP_NAME=${var.app_name}
        - GOOGLE_APPLICATION_CREDENTIALS=/workspace/creds.json
      - name: gcr.io/cloud-builders/gcloud
        entrypoint: bash
        args:
        - -c
        - "gcloud iam service-accounts keys delete $$(grep private_key_id creds.json | cut -f 4 -d '\"') --iam-account=${google_service_account.runner.email}"
      EOF
    )))

    oauth_token {
      service_account_email = google_service_account.runner.email
    }
  }
}
