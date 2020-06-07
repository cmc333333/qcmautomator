resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.app_name

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }
  access {
    role          = "READER"
    special_group = "projectReaders"
  }
  access {
    role          = "WRITER"
    special_group = "projectWriters"
  }
  access {
    role          = "WRITER"
    user_by_email = google_service_account.runner.email
  }
}
