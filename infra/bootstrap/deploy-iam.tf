resource "google_project_iam_binding" "deployer-bigquery" {
  project = google_project.app.project_id
  role    = "roles/bigquery.admin"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
}

resource "google_project_iam_binding" "deployer-build" {
  project = google_project.app.project_id
  role    = "roles/cloudbuild.builds.builder"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
}

resource "google_project_iam_binding" "deployer-iam" {
  project = google_project.app.project_id
  role    = "roles/iam.serviceAccountAdmin"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
}

resource "google_project_iam_binding" "deployer-kms" {
  project = google_project.app.project_id
  role    = "roles/cloudkms.admin"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
}

resource "google_project_iam_binding" "deployer-logging" {
  project = google_project.app.project_id
  role    = "roles/logging.admin"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
}

resource "google_project_iam_binding" "deployer-scheduler" {
  project = google_project.app.project_id
  role    = "roles/cloudscheduler.admin"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
}

resource "google_project_iam_binding" "deployer-storage" {
  project = google_project.app.project_id
  role    = "roles/storage.admin"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
}

resource "google_storage_bucket_iam_member" "deployer-publishes-images" {
  bucket = google_container_registry.registry.id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_project_service_identity.deploy-build.email}"
}

resource "google_service_account_iam_binding" "deployer-acts-as-books-trigger" {
  service_account_id = google_service_account.books-trigger.name
  role               = "roles/iam.serviceAccountUser"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
}

resource "google_service_account_iam_binding" "deployer-acts-as-watching-trigger" {
  service_account_id = google_service_account.watching-trigger.name
  role               = "roles/iam.serviceAccountUser"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
}
