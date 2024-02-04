locals {
  goodreads_shelves = ["read", "currently-reading", "to-read"]
}

resource "google_service_account" "goodreads" {
  account_id = "goodreads"
}

resource "google_project_iam_custom_role" "goodreads" {
  role_id     = "goodreads"
  title       = "Goodreads Project Role"
  description = "Applied to the project"
  permissions = [
    "logging.logEntries.create",
    "run.operations.get",
  ]
}

resource "google_project_iam_binding" "goodreads" {
  project = google_project_service.logging.project
  role    = google_project_iam_custom_role.goodreads.name
  members = [google_service_account.goodreads.member]
}

resource "google_workflows_workflow" "goodreads" {
  project         = google_project_service.workflows.project
  name            = "goodreads"
  service_account = google_service_account.goodreads.email
  # The workflow's very simple, so embed it rather than referencing a yaml file
  source_contents = <<-EOT
    main:
      steps:
      - run:
          call: googleapis.run.v2.projects.locations.jobs.run
          args:
            name: ${google_cloud_run_v2_job.fetch_goodreads.id}
            body: {}
  EOT
}

resource "google_storage_bucket" "goodreads_scripts" {
  name                        = "${google_project_service.storage.project}-goodreads-scripts"
  location                    = "US"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "goodreads_scripts_readers" {
  bucket  = google_storage_bucket.goodreads_scripts.name
  role    = "roles/storage.objectViewer"
  members = [google_service_account.goodreads.member]
}

resource "google_storage_bucket_object" "goodreads_parse_rss_yq" {
  bucket  = google_storage_bucket.goodreads_scripts.name
  name    = "process_rss.yq"
  content = <<-EOT
    .rss.channel.item | map(
      with(
        select(.user_read_at != null);
        .user_read_at |= with_dtf("Mon, 2 Jan 2006 15:04:05 -0700"; format_datetime("2006-01-02T15:04:05Z07:00"))
      )
      | with(select(.book.num_pages != null); .book.num_pages |= from_yaml)
      | with(select(.book_published != null); .book_published |= from_yaml)
      | {
        "goodreads_book_v1": {
          "author_name": .author_name,
          "book_id": .book_id | from_yaml,
          "description": .book_description,
          "guid": .guid,
          "isbn": .isbn,
          "link": .link,
          "num_pages": .book.num_pages,
          "publish_year": .book_published,
          "title": .title,
          "updated_at": .pubDate | with_dtf("Mon, 02 Jan 2006 15:04:05 -0700"; format_datetime("2006-01-02T15:04:05Z07:00")),
          "added_to_shelf_at": .user_date_created | with_dtf("Mon, 02 Jan 2006 15:04:05 -0700"; format_datetime("2006-01-02T15:04:05Z07:00")),
          "read_at": .user_read_at,
          "default_image": .book_image_url,
          "small_image": .book_small_image_url,
          "medium_image": .book_medium_image_url,
          "large_image": .book_large_image_url,
          "goodreads_shelf": strenv(GOODREADS_SHELF)
        }
      }
    ) | .[] 
  EOT
}

# Using run scripts rather than a Docker image to save money
resource "google_storage_bucket_object" "goodreads_run_sh" {
  bucket  = google_storage_bucket.goodreads_scripts.name
  name    = "run.sh"
  content = <<-EOT
    #! /bin/bash
    set -euxo pipefail

    apk add --no-cache yq
    gsutil cp gs://${google_storage_bucket.goodreads_scripts.name}/process_rss.yq .

    %{for shelf in local.goodreads_shelves}
    export GOODREADS_SHELF="${shelf}"
    curl "https://www.goodreads.com/review/list_rss/$${GOODREADS_USER_ID}?shelf=$${GOODREADS_SHELF}" |\
    yq --input-format xml --output-format json --indent 0 --from-file process_rss.yq
    %{endfor}
  EOT
}

resource "google_secret_manager_secret" "goodreads_user_id" {
  project   = google_project_service.secretmanager.project
  secret_id = "goodreads_user_id"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_binding" "goodreads_user_id" {
  secret_id = google_secret_manager_secret.goodreads_user_id.id
  role      = "roles/secretmanager.secretAccessor"
  members   = [google_service_account.goodreads.member]
}

resource "google_cloud_run_v2_job" "fetch_goodreads" {
  project  = google_project_service.run.project
  name     = "fetch-goodreads"
  location = local.region

  template {
    template {
      containers {
        image   = "gcr.io/google.com/cloudsdktool/google-cloud-cli:458.0.1-alpine"
        command = ["/bin/sh"]
        args = [
          "-c",
          "gsutil cat gs://${google_storage_bucket.goodreads_scripts.name}/run.sh | sh"
        ]
        env {
          name = "GOODREADS_USER_ID"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.goodreads_user_id.name
              version = "latest"
            }
          }
        }
        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
      service_account = google_service_account.goodreads.email
    }
  }
}

resource "google_cloud_run_v2_job_iam_binding" "fetch_goodreads_invokers" {
  name     = google_cloud_run_v2_job.fetch_goodreads.name
  location = google_cloud_run_v2_job.fetch_goodreads.location
  role     = "roles/run.invoker"
  members  = [google_service_account.goodreads.member]
}
