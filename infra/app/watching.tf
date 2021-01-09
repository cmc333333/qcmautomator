#resource "google_service_account" "viewing-executor" {
#  account_id = "viewing-executor"
#}
#
#resource "google_service_account_iam_binding" "viewing-executor-act-as" {
#  service_account_id = google_service_account.viewing-executor.name
#  role               = "roles/iam.serviceAccountUser"
#  members            = [
#    "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com",
#  ]
#}
#
#resource "google_storage_bucket" "viewing-secrets" {
#  name                        = "${var.gcp_project_id}-viewing-secrets"
#  uniform_bucket_level_access = true
#}
#
#resource "google_storage_bucket_iam_binding" "viewing-secrets-read" {
#  bucket  = google_storage_bucket.viewing-secrets.name
#  role    = "roles/storage.objectViewer"
#  members = ["serviceAccount:${google_service_account.viewing-executor.email}"]
#}
#
#resource "google_storage_bucket_iam_binding" "viewing-secrets-write" {
#  bucket  = google_storage_bucket.viewing-secrets.name
#  role    = "roles/storage.objectAdmin"
#  members = ["serviceAccount:${google_service_account.viewing-executor.email}"]
#
#  condition {
#    title      = "Can only modify session authentication"
#    expression = "resource.name == 'projects/_/buckets/${google_storage_bucket.viewing-secrets.name}/session.enc"
#  }
#}
#
#resource "google_kms_key_ring" "viewing" {
#  name     = "viewing"
#  location = "us"
#}
#
#resource "google_kms_crypto_key" "viewing-secrets" {
#  name     = "secrets"
#  key_ring = google_kms_key_ring.viewing.id
#}
#
#resource "google_kms_crypto_key_iam_binding" "viewing-secrets" {
#  crypto_key_id = google_kms_crypto_key.books-secrets.id
#  members       = ["serviceAccount:${google_service_account.books-executor.email}"]
#  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
#}
