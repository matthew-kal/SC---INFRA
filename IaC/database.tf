# MySQL DB

resource "random_password" "db_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_database_instance" "main_db" {
  project             = var.gcp_project_id
  name                = "sc-db-instance-prod"
  database_version    = "MYSQL_8_0"
  region              = var.gcp_region
  deletion_protection = true 

  settings {
    tier              = "db-f1-micro" 
    
    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.main_vpc.id
    }

    backup_configuration {
      enabled = true
    }

  }
  depends_on = [google_service_networking_connection.default]
}

resource "google_sql_database" "main_database" {
  project  = var.gcp_project_id
  name     = "sc-db"
  instance = google_sql_database_instance.main_db.name
}

resource "google_sql_user" "db_user" {
  project  = var.gcp_project_id
  name     = "sc_user"
  instance = google_sql_database_instance.main_db.name
  password = random_password.db_password.result
}