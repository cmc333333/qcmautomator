resource "google_service_account" "fitbit" {
  account_id = "fitbit"
}

resource "google_project_iam_member" "fitbit_logging" {
  project = google_project_service.logging.project
  role    = "roles/logging.logWriter"
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
