resource "google_project" "deploy" {
  name                = "Quantified CM Automator Deploy"
  project_id          = "${var.gcp_project_id}-deploy"
  auto_create_network = false
  billing_account     = var.gcp_billing_account
}

resource "google_project_service" "build-bigquery" {
  project = google_project.deploy.project_id
  service = "bigquery.googleapis.com"
}

resource "google_project_service" "build-deploy" {
  project = google_project.deploy.project_id
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "iam-deploy" {
  project = google_project.deploy.project_id
  service = "iam.googleapis.com"
}

resource "google_project_service" "resourcemanager-deploy" {
  project = google_project.deploy.project_id
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_storage_bucket" "deploy-state" {
  project                     = google_project.deploy.project_id
  name                        = "${var.gcp_project_id}-deploy-state"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

resource "google_project_service_identity" "deploy-build" {
  provider   = google-beta
  project    = google_project.deploy.project_id
  service    = "cloudbuild.googleapis.com"
  depends_on = [google_project_service.build-deploy]
}

resource "google_storage_bucket_iam_binding" "deploy-state" {
  bucket = google_storage_bucket.deploy-state.name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_project_service_identity.deploy-build.email}"
  ]
  condition {
    title      = "Can modify deployment state file"
    expression = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.deploy-state.name}/objects/app/')"
  }
}

resource "google_cloudbuild_trigger" "auto-deploy" {
  provider = google-beta 
  project  = google_project.deploy.project_id
  filename = "cloudbuild.yaml"
  github {
    owner = "cmc333333"
    name  = "qcmautomator"
    push {
      branch = "^main$"
    }
  }
}

resource "google_container_registry" "registry" {
  project    = google_project.app.project_id
  depends_on = [google_project_service.storage-app]
}
