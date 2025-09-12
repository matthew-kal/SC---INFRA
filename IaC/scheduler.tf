# Automated Cron Job

resource "google_cloud_scheduler_job" "daily_user_refresh" {
  project     = var.gcp_project_id
  name        = "daily-user-data-refresh"
  description = "Triggers the daily refresh of data for all users."
  schedule    = "0 2 * * *" 
  time_zone   = "America/New_York"
  attempt_deadline = "320s"

  http_target {
    uri = "https://api.surgicalm.com/users/cron/refresh-all-user-data/"
    http_method = "POST"
    
    headers = {
      "Content-Type"         = "application/json"
    }

    oidc_token {
      service_account_email = google_service_account.cloud_run_sa.email
      audience              = "https://api.surgicalm.com"
    }
    
  }
}