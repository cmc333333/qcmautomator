terraform {
  backend "gcs" {
    bucket                      = "qcmautomator-deployment-state"
    impersonate_service_account = "deployer@qcmautomator.iam.gserviceaccount.com"
    prefix                      = "bootstrap"
  }

  required_providers {
    google = "~> 5.9.0"
  }
}

locals {
  project = "qcmautomator"
  region  = "us-west1"
}

provider "google" {
  project                     = local.project
  impersonate_service_account = "deployer@qcmautomator.iam.gserviceaccount.com"
  region                      = local.region
}
