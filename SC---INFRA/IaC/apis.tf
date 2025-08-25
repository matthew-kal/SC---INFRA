# GCP Access 

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com",
    "iam.googleapis.com",
    "cloudscheduler.googleapis.com",
  ])
  service                    = each.key
  disable_on_destroy         = false
}