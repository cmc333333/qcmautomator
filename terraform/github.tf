resource "google_service_account" "github" {
  account_id = "github"
}

resource "google_secret_manager_secret" "github_token" {
  project   = google_project_service.secretmanager.project
  secret_id = "github_token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_binding" "github_token_access" {
  secret_id = google_secret_manager_secret.github_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members   = [google_service_account.github.member]
}

resource "google_project_iam_member" "github_logging" {
  project = google_project_service.logging.project
  role    = "roles/logging.logWriter"
  member  = google_service_account.github.member
}

resource "google_workflows_workflow" "github_events" {
  project         = google_project_service.workflows.project
  name            = "github_events"
  service_account = google_service_account.github.email
  source_contents = file("../workflows/github/events.workflows.yml")
}

resource "google_project_iam_member" "github_bq_user" {
  project = google_project_service.bigquery.project
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.github.member
}

resource "google_bigquery_dataset" "github" {
  dataset_id = "github"
}

resource "google_bigquery_dataset_access" "github_reading" {
  dataset_id    = google_bigquery_dataset.github.dataset_id
  role          = "READER"
  user_by_email = google_service_account.github.email
}

resource "google_bigquery_table" "github_latest_id" {
  dataset_id          = google_bigquery_dataset.github.dataset_id
  table_id            = "latest_id"
  deletion_protection = false
  view {
    use_legacy_sql = false
    query          = <<-EOT
      SELECT MAX(jsonPayload.github_event_v1.id) AS id
      FROM `${google_bigquery_dataset.raw_data.dataset_id}.Workflows`
    EOT
  }
}

resource "google_bigquery_dataset_access" "raw_data_github" {
  dataset_id = google_bigquery_dataset.raw_data.dataset_id
  dataset {
    target_types = ["VIEWS"]
    dataset {
      project_id = google_bigquery_dataset.github.project
      dataset_id = google_bigquery_dataset.github.dataset_id
    }
  }
}
