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

data "google_secret_manager_secret_version" "secrets" {
  provider = google-beta
  secret   = "${var.app_name}-terraform"
}

resource "google_cloudbuild_trigger" "run" {
  for_each  = yamldecode(
    data.google_secret_manager_secret_version.secrets.secret_data
  ).cron
  provider = google-beta

  name = "run-${var.app_name}-${each.key}"
  github {
    owner = "cmc333333"
    name  = "qcmautomator"
    push {
      branch = "master"
    }
  }
  build {
    tags = ["run", var.app_name, "run-${var.app_name}-${each.key}"]
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = ["iam", "service-accounts", "keys", "create", "creds.json", "--iam-account=${google_service_account.runner.email}"]
    }
    step {
      name = "gcr.io/${var.gcp_project_id}/${var.app_name}"
      args = [each.key]
      env  = [
        "GCP_PROJECT_ID=${var.gcp_project_id}",
        "APP_NAME=${var.app_name}",
        "GOOGLE_APPLICATION_CREDENTIALS=/workspace/creds.json"
      ]
    }
    step {
      name       = "gcr.io/cloud-builders/gcloud"
      entrypoint = "bash"
      args = ["-c", "gcloud iam service-accounts keys delete $$(grep private_key_id creds.json | cut -f 4 -d '\"') --iam-account=${google_service_account.runner.email}"]
    }
  }
}

resource "google_cloud_scheduler_job" "run" {
  for_each  = yamldecode(
    data.google_secret_manager_secret_version.secrets.secret_data
  ).cron
  name      = google_cloudbuild_trigger.run[each.key].name
  region    = "us-central1"
  schedule  = each.value
  time_zone = "America/New_York"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/${google_cloudbuild_trigger.run[each.key].id}:run"
    body        = base64encode("{\"branchName\":\"master\"}")

    oauth_token {
      service_account_email = google_service_account.runner.email
    }
  }
}
