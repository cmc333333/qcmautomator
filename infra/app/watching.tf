data "google_service_account" "watching-executor" {
  account_id = "watching-executor"
}

data "google_service_account" "watching-trigger" {
  account_id = "watching-trigger"
}

resource "google_service_account_iam_binding" "watching-executor-act-as" {
  service_account_id = data.google_service_account.watching-executor.name
  role               = "roles/iam.serviceAccountUser"
  members            = ["serviceAccount:${data.google_service_account.watching-trigger.email}"]
}

resource "google_storage_bucket_iam_member" "watching-secrets-listing" {
  bucket = google_storage_bucket.secrets.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${data.google_service_account.watching-executor.email}"
}

resource "google_storage_bucket_iam_member" "watching-secrets" {
  bucket = google_storage_bucket.secrets.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_service_account.watching-executor.email}"
  condition {
    title      = "Can read watching secrets"
    expression = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.secrets.name}/objects/watching/')"
  }
}

resource "google_storage_bucket_iam_member" "watching-trakt-update" {
  bucket = google_storage_bucket.secrets.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_service_account.watching-executor.email}"
  condition {
    title      = "Can update trakt refresh token"
    expression = "resource.name == 'projects/_/buckets/${google_storage_bucket.secrets.name}/objects/watching/trakt_refresh_token'"
  }
}

resource "google_storage_bucket" "watching-secrets" {
  name                        = "${data.google_project.project.project_id}-watching-secrets"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "watching-secrets-reader" {
  bucket  = google_storage_bucket.watching-secrets.name
  role    = "roles/storage.objectViewer"
  members = ["serviceAccount:${data.google_service_account.watching-executor.email}"]
}

resource "google_cloud_scheduler_job" "execute-viewing" {
  name      = "execute-watching"
  schedule  = "40 * * * *"
  time_zone = "America/New_York"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${data.google_project.project.project_id}/builds"
    body = base64encode(jsonencode(yamldecode(file(
      "${path.module}/build-defs/watching.yaml"
    ))))

    oauth_token {
      service_account_email = data.google_service_account.watching-trigger.email
    }
  }
}

resource "google_bigquery_dataset" "watching_loading" {
  dataset_id                  = "watching_loading"
  description                 = "Loading area for watching data"
  default_table_expiration_ms = 3600000 # one hour
}

resource "google_bigquery_dataset_iam_binding" "watching_loading-writer" {
  dataset_id = google_bigquery_dataset.watching_loading.dataset_id
  role       = "roles/bigquery.dataEditor"
  members    = ["serviceAccount:${data.google_service_account.watching-executor.email}"]
}

resource "google_bigquery_dataset" "watching" {
  dataset_id = "watching"
}

resource "google_bigquery_dataset_iam_binding" "watching-writer" {
  dataset_id = google_bigquery_dataset.watching.dataset_id
  role       = "roles/bigquery.dataEditor"
  members    = ["serviceAccount:${data.google_service_account.watching-executor.email}"]
}
