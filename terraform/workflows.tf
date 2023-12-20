resource "google_service_account" "scheduler" {
  account_id = "scheduler"
}

resource "google_project_iam_member" "scheduler_triggers_workflows" {
  project = google_project_service.cloudscheduler.project
  role    = "roles/workflows.invoker"
  member  = google_service_account.scheduler.member
}