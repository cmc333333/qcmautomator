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

provider "google" {
  project                     = "qcmautomator"
  impersonate_service_account = "deployer@qcmautomator.iam.gserviceaccount.com"
  region                      = "us-west1"
}
