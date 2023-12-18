resource "google_bigquery_dataset" "raw_data" {
  dataset_id = "raw_data"
}

resource "google_logging_project_sink" "raw_data" {
  name                   = "raw_data"
  destination            = "bigquery.googleapis.com/${google_bigquery_dataset.raw_data.id}"
  unique_writer_identity = true
  filter                 = <<-EOT
    logName="projects/qcmautomator/logs/Workflows"
    resource.type="workflows.googleapis.com/Workflow"
    resource.labels.workflow_id="${google_workflows_workflow.fitbit_sleep.name}"
    jsonPayload.fitbit_sleep_v1:*
  EOT
  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_bigquery_dataset_access" "raw_data_writer" {
  dataset_id    = google_bigquery_dataset.raw_data.dataset_id
  role          = "WRITER"
  user_by_email = replace(google_logging_project_sink.raw_data.writer_identity, "serviceAccount:", "")
}