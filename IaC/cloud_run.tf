# Serverless API Environment

resource "random_string" "service_url_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "google_artifact_registry_repository" "api_repo" {
  project       = var.gcp_project_id
  location      = var.gcp_region
  repository_id = "surgicalm-api-repo"
  format        = "DOCKER"
}

resource "google_service_account" "cloud_run_sa" {
  project      = var.gcp_project_id
  account_id   = "surgicalm-api-sa"
  display_name = "Service Account for SurgiCalm API"
}

data "google_iam_policy" "no_run_users" {
  binding {
    role    = "roles/run.invoker"
    members = ["allUsers"]
  }
}

resource "google_cloud_run_v2_service_iam_policy" "noauth" {
  project     = google_cloud_run_v2_service.django_api.project
  location    = google_cloud_run_v2_service.django_api.location
  name        = google_cloud_run_v2_service.django_api.name
  policy_data = data.google_iam_policy.no_run_users.policy_data
}

resource "google_project_iam_member" "secret_accessor" {
  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "sql_client" {
  project = var.gcp_project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_storage_bucket_iam_member" "gcs_admin" {
  bucket = google_storage_bucket.media_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "token_creator" {
  project = var.gcp_project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Allow the service account to impersonate itself for signed URL generation
resource "google_service_account_iam_member" "self_impersonation" {
  service_account_id = google_service_account.cloud_run_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_cloud_run_v2_service" "django_api" {
  project  = var.gcp_project_id
  name     = "surgicalm-api"
  location = var.gcp_region

  template {
    service_account = google_service_account.cloud_run_sa.email
    vpc_access {
      connector = google_vpc_access_connector.serverless_connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.api_repo.repository_id}/api:latest"

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "ENVIRONMENT"
        value = "production"
      }
      env {
        name  = "DEBUG"
        value = "False"
      }
      env {
        name  = "ALLOWED_HOSTS"
        value = ".run.app,api.surgicalm.com,admin.surgicalm.com"
      }
      env {
        name  = "CSRF_TRUSTED_ORIGINS"
        value = "https://surgicalm-api-${random_string.service_url_suffix.result}.${var.gcp_region}.run.app"
      }
      env {
        name  = "BASE_URL"
        value = "https://api.surgicalm.com"
      }
      env {
        name = "SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.django_secret_key.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "DATABASE_NAME"
        value = google_sql_database.main_database.name
      }
      env {
        name  = "DATABASE_USER"
        value = google_sql_user.db_user.name
      }
      env {
        name  = "DATABASE_HOST"
        value = google_sql_database_instance.main_db.private_ip_address
      }
      env {
        name = "DATABASE_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "STORAGE_BUCKET_NAME"
        value = google_storage_bucket.media_bucket.name
      }
      env {
        name  = "DATABASE_PORT"
        value = 3306
      }
      env {
        name = "CRON_SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.cron_secret_key.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "DEV_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.dev_key.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "EMAIL_HOST_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.email_password.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "EMAIL_HOST_USERNAME"
        value = "admin@surgicalm.com"
      }
      env {
        name  = "DEFAULT_FROM_EMAIL"
        value = "admin@surgicalm.com"
      }
      env {
        name  = "SERVICE_ACCOUNT_EMAIL"
        value = google_service_account.cloud_run_sa.email
      }
    }
  }
}