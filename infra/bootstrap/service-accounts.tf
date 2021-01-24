resource "google_service_account" "books-executor" {
  project    = google_project.app.project_id
  account_id = "books-executor"
}

resource "google_project_iam_member" "books-can-run-jobs" {
  project = google_project.app.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.books-executor.email}"
}

resource "google_service_account" "books-trigger" {
  project    = google_project.app.project_id
  account_id = "books-trigger"
}

resource "google_project_iam_member" "books-trigger" {
  project = google_project.app.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.books-trigger.email}"
}

resource "google_service_account" "watching-executor" {
  project    = google_project.app.project_id
  account_id = "watching-executor"
}

resource "google_project_iam_member" "watching-can-run-jobs" {
  project = google_project.app.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.watching-executor.email}"
}

resource "google_service_account" "watching-trigger" {
  project    = google_project.app.project_id
  account_id = "watching-trigger"
}

resource "google_project_iam_member" "watching-trigger" {
  project = google_project.app.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.watching-trigger.email}"
}
