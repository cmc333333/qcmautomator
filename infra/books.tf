resource "google_logging_project_sink" "books" {
  name                   = "books"
  destination            = "bigquery.googleapis.com/projects/${var.gcp_project_id}/datasets/${google_bigquery_dataset.events.dataset_id}"
  filter                 = "logName=\"projects/${var.gcp_project_id}/logs/books\""
  unique_writer_identity = true

  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_bigquery_dataset_iam_member" "books-sink" {
  dataset_id = google_bigquery_dataset.events.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.books.writer_identity
}

resource "google_service_account" "books-executor" {
  account_id = "books-executor"
}

resource "google_service_account_iam_binding" "books-executor-act-as" {
  service_account_id = google_service_account.books-executor.name
  role               = "roles/iam.serviceAccountUser"
  members            = [
    "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com",
  ]
}

resource "google_storage_bucket" "books-secrets" {
  name                        = "${var.gcp_project_id}-books-secrets"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "books-secrets-reader" {
  bucket  = google_storage_bucket.books-secrets.name
  role    = "roles/storage.objectViewer"
  members = ["serviceAccount:${google_service_account.books-executor.email}"]
}

resource "google_kms_key_ring" "books" {
  name     = "books"
  location = "us"
}

resource "google_kms_crypto_key" "books-secrets" {
  name     = "secrets"
  key_ring = google_kms_key_ring.books.id
}

resource "google_kms_crypto_key_iam_binding" "books-secrets" {
  crypto_key_id = google_kms_crypto_key.books-secrets.id
  members       = ["serviceAccount:${google_service_account.books-executor.email}"]
  role          = "roles/cloudkms.cryptoKeyDecrypter"
}

resource "google_cloud_scheduler_job" "execute" {
  name      = "execute-books"
  schedule  = "30 * * * *"
  time_zone = "America/New_York"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${var.gcp_project_id}/builds"
    body        = base64encode(jsonencode(yamldecode(file(
      "${path.module}/../build-defs/books.yaml"
    ))))

    oauth_token {
      # self
      service_account_email = "deployer@${var.gcp_project_id}.iam.gserviceaccount.com"
    }
  }
}
