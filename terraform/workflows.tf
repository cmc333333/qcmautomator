resource "google_service_account" "scheduler" {
  account_id = "scheduler"
}

resource "google_project_iam_member" "scheduler_triggers_workflows" {
  project = google_project_service.cloudscheduler.project
  role    = "roles/workflows.invoker"
  member  = google_service_account.scheduler.member
}

resource "google_workflows_workflow" "hourly" {
  project         = google_project_service.workflows.project
  name            = "hourly"
  service_account = google_service_account.scheduler.email
  source_contents = file("../workflows/hourly.workflows.yml")

  user_env_vars = {
    FITBIT_SLEEP_WORKFLOW_ID = google_workflows_workflow.fitbit_sleep.name
  }
}

resource "google_cloud_scheduler_job" "hourly" {
  project     = google_project_service.cloudscheduler.project
  name        = "hourly"
  description = "Trigger the 'hourly' workflow, every hour"
  schedule    = "5 * * * *"
  time_zone   = "America/New_York"

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.hourly.id}/executions"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}
