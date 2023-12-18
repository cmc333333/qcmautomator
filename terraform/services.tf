resource "google_project_service" "logging" {
  service = "logging.googleapis.com"
}

resource "google_project_service" "workflows" {
  service = "workflows.googleapis.com"
}