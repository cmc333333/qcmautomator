resource "google_project_service" "iam" {
  service                    = "iam.googleapis.com"
  disable_dependent_services = true
}

resource "google_service_account" "runner" {
  account_id = "${var.app_name}-runner"

  depends_on = [google_project_service.iam]
}

resource "google_project_iam_member" "trigger_builds" {
  role   = "roles/cloudbuild.builds.editor"
  member = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_secret_manager_secret_iam_binding" "access" {
  provider  = google-beta
  secret_id = var.app_name
  role      = "roles/secretmanager.secretAccessor"
  members   = ["serviceAccount:${google_service_account.runner.email}"]
}

resource "google_project_iam_member" "run_queries" {
  role   = "roles/bigquery.jobUser"
  member = "serviceAccount:${google_service_account.runner.email}"
}
