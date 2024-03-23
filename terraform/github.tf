resource "google_service_account" "github" {
  account_id = "github"
}

resource "google_secret_manager_secret" "github_token" {
  project   = google_project_service.secretmanager.project
  secret_id = "github_token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_binding" "github_token_access" {
  secret_id = google_secret_manager_secret.github_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members   = [google_service_account.github.member]
}

resource "google_project_iam_member" "github_logging" {
  project = google_project_service.logging.project
  role    = "roles/logging.logWriter"
  member  = google_service_account.github.member
}

resource "google_workflows_workflow" "github_events" {
  project         = google_project_service.workflows.project
  name            = "github_events"
  service_account = google_service_account.github.email
  source_contents = file("../workflows/github/events.workflows.yml")
}
