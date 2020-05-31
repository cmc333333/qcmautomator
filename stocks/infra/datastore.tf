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

resource "google_bigquery_table" "price" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = "price"

  schema = <<EOF
    [
      {
        "name": "date",
        "type": "DATE",
        "mode": "REQUIRED"
      },
      {
        "name": "symbol",
        "type": "STRING",
        "mode": "REQUIRED"
      },
      {
        "name": "avg_price",
        "type": "NUMERIC",
        "mode": "REQUIRED"
      }
    ]
  EOF
}
