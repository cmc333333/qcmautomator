terraform {
  backend "gcs" {
    bucket                      = "qcmautomator-deployment-state"
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
  project = local.project
  region                      = local.region
}
