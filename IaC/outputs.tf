# Outputs

output "cloud_run_service_url" {
  description = "The publicly accessible URL of the Cloud Run service."
  value       = google_cloud_run_v2_service.django_api.uri
}

output "cloud_sql_instance_name" {
  description = "The connection name of the Cloud SQL instance."
  value       = google_sql_database_instance.main_db.connection_name
}

output "media_bucket_name" {
  description = "The name of the GCS bucket for media and static files."
  value       = google_storage_bucket.media_bucket.name
}
