data "google_service_account" "books-executor" {
  account_id = "books-executor"
}

data "google_service_account" "books-trigger" {
  account_id = "books-trigger"
}

resource "google_service_account_iam_binding" "books-executor-act-as" {
  service_account_id = data.google_service_account.books-executor.name
  role               = "roles/iam.serviceAccountUser"
  members = [
    "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com",
  ]
}

resource "google_storage_bucket_iam_member" "books-secrets-listing" {
  bucket = google_storage_bucket.secrets.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${data.google_service_account.books-executor.email}"
}

resource "google_storage_bucket_iam_member" "books-secrets" {
  bucket = google_storage_bucket.secrets.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_service_account.books-executor.email}"
  condition {
    title      = "Can read book secrets"
    expression = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.secrets.name}/objects/books/')"
  }
}

resource "google_storage_bucket" "books-secrets" {
  name                        = "${data.google_project.project.project_id}-books-secrets"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "books-secrets-reader" {
  bucket  = google_storage_bucket.books-secrets.name
  role    = "roles/storage.objectViewer"
  members = ["serviceAccount:${data.google_service_account.books-executor.email}"]
}

resource "google_cloud_scheduler_job" "execute" {
  name      = "execute-books"
  schedule  = "30 * * * *"
  time_zone = "America/New_York"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${data.google_project.project.project_id}/builds"
    body = base64encode(jsonencode(yamldecode(file(
      "${path.module}/build-defs/books.yaml"
    ))))

    oauth_token {
      service_account_email = data.google_service_account.books-trigger.email
    }
  }
}

resource "google_bigquery_dataset" "books_loading" {
  dataset_id                  = "books_loading"
  description                 = "Loading area for book data"
  default_table_expiration_ms = 3600000 # one hour
}

resource "google_bigquery_dataset_iam_binding" "books_loading-writer" {
  dataset_id = google_bigquery_dataset.books_loading.dataset_id
  role       = "roles/bigquery.dataEditor"
  members    = ["serviceAccount:${data.google_service_account.books-executor.email}"]
}

resource "google_bigquery_dataset" "books" {
  dataset_id = "books"
}

resource "google_bigquery_dataset_iam_binding" "books-writer" {
  dataset_id = google_bigquery_dataset.books.dataset_id
  role       = "roles/bigquery.dataEditor"
  members    = ["serviceAccount:${data.google_service_account.books-executor.email}"]
}
