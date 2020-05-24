#!/bin/bash

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $(basename "$0") PROJECT_ID APP_NAME"
    exit 1
fi

gcp_project_id=$1
app_name=$2

image_digest=$(
  gcloud container images list-tags gcr.io/$gcp_project_id/$app_name \
  --filter="tags:latest" --format="get(digest)"
)
echo "image_digest=\"$image_digest\"" > terraform.tfvars
echo "app_name=\"$app_name\"" >> terraform.tfvars
echo "gcp_project_id=\"$gcp_project_id\"" >> terraform.tfvars

terraform init -input=false \
  -backend-config=bucket=qcmautomator_tfstate \
  -backend-config=prefix=$app_name
terraform apply -auto-approve
