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

locals {
  url_schema = <<-EOF
    "type": "RECORD",
    "mode": "REQUIRED",
    "fields": [
      {
        "name": "raw",
        "type": "STRING",
        "mode": "REQUIRED"
      },
      {
        "name": "normalized",
        "type": "STRING",
        "mode": "REQUIRED"
      },
      {
        "name": "domain",
        "type": "STRING",
        "mode": "REQUIRED"
      },
      {
        "name": "base_name",
        "type": "STRING",
        "mode": "REQUIRED"
      }
    ]
  EOF
}

resource "google_bigquery_table" "episode_actions" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = "episode_actions"

  schema = <<EOF
    [
      {
        "name": "podcast",
        ${local.url_schema}
      },
      {
        "name": "episode",
        ${local.url_schema}
      },
      {
        "name": "action",
        "type": "STRING",
        "mode": "REQUIRED"
      },
      {
        "name": "device",
        "type": "STRING",
        "mode": "REQUIRED"
      },
      {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
      },
      {
        "name": "started",
        "type": "INT64",
        "mode": "NULLABLE"
      },
      {
        "name": "position",
        "type": "INT64",
        "mode": "NULLABLE"
      },
      {
        "name": "total",
        "type": "INT64",
        "mode": "NULLABLE"
      }
    ]
  EOF
}
