resource "google_storage_bucket" "secrets" {
  name                        = "${data.google_project.project.project_id}-secrets"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}
