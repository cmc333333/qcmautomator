resource "google_service_account" "fitbit" {
  account_id = "fitbit"
}

resource "google_project_iam_member" "fitbit_logging" {
  project = google_project_service.logging.project
  role    = "roles/logging.logWriter"
  member  = google_service_account.fitbit.member
}

resource "google_project_iam_member" "fitbit_bq_user" {
  project = google_project_service.bigquery.project
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.fitbit.member
}

resource "google_storage_bucket" "fitbit_refresh_token" {
  project                     = "qcmautomator"
  name                        = "qcmautomator-fitbit-refresh-token"
  location                    = "US"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "fitbit_refresh_token_user" {
  bucket  = google_storage_bucket.fitbit_refresh_token.name
  role    = "roles/storage.objectUser"
  members = [google_service_account.fitbit.member]
}

resource "google_workflows_workflow" "fitbit_sleep" {
  project         = google_project_service.workflows.project
  name            = "fitbit_sleep"
  service_account = google_service_account.fitbit.email
  source_contents = file("../workflows/fitbit/sleep.workflows.yml")

  user_env_vars = {
    CLIENT_ID            = "22BMN7"
    REFRESH_TOKEN_BUCKET = google_storage_bucket.fitbit_refresh_token.name
  }
}

resource "google_bigquery_table" "raw_data_fitbit_sleep" {
  dataset_id          = google_bigquery_dataset.raw_data.dataset_id
  table_id            = "fitbit_sleep"
  deletion_protection = false
  materialized_view {
    enable_refresh = false # Cost savings
    query          = <<-EOT
      SELECT timestamp AS ingestion_time, record
      FROM `${google_bigquery_dataset.raw_data.dataset_id}.Workflows`
      INNER JOIN UNNEST(jsonPayload.fitbit_sleep_v1) AS record
      WHERE jsonPayload.fitbit_sleep_v1 IS NOT NULL
    EOT
  }
}

resource "google_bigquery_dataset" "fitbit" {
  dataset_id = "fitbit"
}

resource "google_bigquery_dataset_access" "fitbit_reading" {
  dataset_id    = google_bigquery_dataset.fitbit.dataset_id
  role          = "READER"
  user_by_email = google_service_account.fitbit.email
}

resource "google_bigquery_table" "fitbit_sleep" {
  dataset_id          = google_bigquery_dataset.fitbit.dataset_id
  table_id            = "sleep"
  deletion_protection = false
  view {
    use_legacy_sql = false
    # Dedupes 
    query = <<-EOT
      SELECT MAX_BY(record, ingestion_time).*
      FROM ${google_bigquery_table.raw_data_fitbit_sleep.dataset_id}.${google_bigquery_table.raw_data_fitbit_sleep.table_id}
      GROUP BY record.logid
    EOT
  }
}

resource "google_bigquery_dataset_access" "raw_data_fitbit" {
  dataset_id = google_bigquery_dataset.raw_data.dataset_id
  dataset {
    target_types = ["VIEWS"]
    dataset {
      project_id = google_bigquery_dataset.fitbit.project
      dataset_id = google_bigquery_dataset.fitbit.dataset_id
    }
  }
}
