terraform {
  backend "gcs" {
    # bucket is provided at init time
    prefix = "bootstrap"
  }
  required_providers {
    google      = "~> 3.51.1"
    google-beta = "~> 3.51.1"
  }
}

provider "google" {}
provider "google-beta" {}

resource "google_project" "app" {
  name                = "Quantified CM Automator"
  project_id          = var.gcp_project_id
  auto_create_network = false
  billing_account     = var.gcp_billing_account
}
