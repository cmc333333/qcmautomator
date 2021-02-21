data "google_service_account" "podcasts-executor" {
  account_id = "podcasts-executor"
}

data "google_service_account" "podcasts-trigger" {
  account_id = "podcasts-trigger"
}

resource "google_service_account_iam_binding" "podcasts-executor-act-as" {
  service_account_id = data.google_service_account.podcasts-executor.name
  role               = "roles/iam.serviceAccountUser"
  members            = ["serviceAccount:${data.google_service_account.podcasts-trigger.email}"]
}

resource "google_storage_bucket_iam_member" "podcasts-secrets-listing" {
  bucket = google_storage_bucket.secrets.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${data.google_service_account.podcasts-executor.email}"
}

resource "google_storage_bucket_iam_member" "podcasts-secrets" {
  bucket = google_storage_bucket.secrets.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_service_account.podcasts-executor.email}"
  condition {
    title      = "Can read podcasts secrets"
    expression = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.secrets.name}/objects/podcasts/')"
  }
}

resource "google_cloud_scheduler_job" "execute-podcasts" {
  name      = "execute-podcasts"
  schedule  = "10 * * * *"
  time_zone = "America/New_York"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${data.google_project.project.project_id}/builds"
    body = base64encode(jsonencode(yamldecode(file(
      "${path.module}/build-defs/podcasts.yaml"
    ))))

    oauth_token {
      service_account_email = data.google_service_account.podcasts-trigger.email
    }
  }
}

resource "google_bigquery_dataset" "podcasts_loading" {
  dataset_id                  = "podcasts_loading"
  description                 = "Loading area for podcast data"
  default_table_expiration_ms = 3600000 # one hour
}

resource "google_bigquery_dataset_iam_binding" "podcasts_loading-writer" {
  dataset_id = google_bigquery_dataset.podcasts_loading.dataset_id
  role       = "roles/bigquery.dataEditor"
  members    = ["serviceAccount:${data.google_service_account.podcasts-executor.email}"]
}

resource "google_bigquery_dataset" "podcasts" {
  dataset_id = "podcasts"
}

resource "google_bigquery_dataset_iam_binding" "podcasts-writer" {
  dataset_id = google_bigquery_dataset.podcasts.dataset_id
  role       = "roles/bigquery.dataEditor"
  members    = ["serviceAccount:${data.google_service_account.podcasts-executor.email}"]
}


