resource "google_storage_bucket" "build-logs" {
  name                        = "${data.google_project.project.project_id}-build-logs"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "logs-writer" {
  bucket  = google_storage_bucket.build-logs.name
  role    = "roles/storage.admin"
  members = [
    "serviceAccount:${data.google_service_account.books-executor.email}",
    "serviceAccount:${data.google_service_account.watching-executor.email}",
  ]
}
