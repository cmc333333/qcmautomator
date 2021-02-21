resource "google_container_registry" "registry" {}

resource "google_storage_bucket_iam_member" "books-reads-container" {
  bucket = google_container_registry.registry.id
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_service_account.books-executor.email}"
}

resource "google_storage_bucket_iam_member" "podcasts-reads-container" {
  bucket = google_container_registry.registry.id
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_service_account.podcasts-executor.email}"
}

resource "google_storage_bucket_iam_member" "watching-reads-container" {
  bucket = google_container_registry.registry.id
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_service_account.watching-executor.email}"
}
