resource "google_project_service" "bigquery-app" {
  project = google_project.app.project_id
  service = "bigquery.googleapis.com"
}

resource "google_project_service" "build-app" {
  project = google_project.app.project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "iam-app" {
  project = google_project.app.project_id
  service = "iam.googleapis.com"
}

resource "google_project_service" "kms-app" {
  project = google_project.app.project_id
  service = "cloudkms.googleapis.com"
}

resource "google_project_service" "logging-app" {
  project = google_project.app.project_id
  service = "logging.googleapis.com"
}

resource "google_project_service" "scheduler-app" {
  project = google_project.app.project_id
  service = "cloudscheduler.googleapis.com"
}

resource "google_project_service" "storage-app" {
  project = google_project.app.project_id
  service = "storage-component.googleapis.com"
}
