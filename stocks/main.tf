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

resource "google_service_account" "cron" {
  account_id = "${var.app_name}-cron"

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

resource "google_cloud_run_service_iam_binding" "binding" {
  location    = google_cloud_run_service.app.location
  project     = google_cloud_run_service.app.project
  service     = google_cloud_run_service.app.name
  role        = "roles/run.invoker"
  members     = [
    "serviceAccount:${google_service_account.cron.email}",
  ]
}

data "google_secret_manager_secret_version" "secrets" {
  provider = google-beta
  secret   = "${var.app_name}-terraform"
}

resource "google_cloud_scheduler_job" "job" {
  for_each  = yamldecode(
    data.google_secret_manager_secret_version.secrets.secret_data
  ).cron
  name      = each.key
  region    = "us-central1"
  schedule  = each.value
  time_zone = "America/New_York"

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_service.app.status[0].url}/${each.key}"

    oidc_token {
      service_account_email = google_service_account.cron.email
    }
  }
}

resource "google_secret_manager_secret_iam_binding" "access" {
  provider  = google-beta
  secret_id = var.app_name
  role      = "roles/secretmanager.secretAccessor"
  members   = ["serviceAccount:${google_service_account.runner.email}"]
}

resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.app_name

  access {
    role          = "roles/bigquery.dataOwner"
    special_group = "projectOwners"
  }
  access {
    role          = "roles/bigquery.dataViewer"
    special_group = "projectReaders"
  }
  access {
    role          = "roles/bigquery.dataEditor"
    special_group = "projectWriters"
  }
  access {
    role          = "roles/bigquery.dataEditor"
    user_by_email = google_service_account.runner.email
  }
}

resource "google_bigquery_table" "price" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = "price"
  clustering = ["symbol", "date"]

  time_partitioning {
    field = "date"
    type  = "DAY"
  }

  schema = <<EOF
    [
      {
        "name": "date",
        "type": "DATE",
        "mode": "REQUIRED"
      },
      {
        "name": "inserted_at",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
      },
      {
        "name": "symbol",
        "type": "STRING",
        "mode": "REQUIRED"
      },
      {
        "name": "avg_price",
        "type": "NUMERIC",
        "mode": "REQUIRED"
      }
    ]
  EOF
}

output "service_url" {
  value = google_cloud_run_service.app.status[0].url
}
