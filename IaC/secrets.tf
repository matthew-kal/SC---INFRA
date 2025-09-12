# Secret Env Variables

resource "random_string" "dev_key_value" {
  length  = 48
  special = false
}

resource "google_secret_manager_secret" "django_secret_key" {
  project   = var.gcp_project_id
  secret_id = "django-secret-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "db_password" {
  project   = var.gcp_project_id
  secret_id = "db-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password_v1" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "dev_key" {
  project   = var.gcp_project_id
  secret_id = "dev-key"
  replication {
    auto {}
  }
}
resource "google_secret_manager_secret_version" "dev_key_v1" {
  secret      = google_secret_manager_secret.dev_key.id
  secret_data = random_string.dev_key_value.result
}

resource "google_secret_manager_secret" "email_password" {
  project   = var.gcp_project_id
  secret_id = "email-password"
  replication {
    auto {}
  }
}