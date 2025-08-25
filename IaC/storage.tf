# Storage Bucket

resource "google_storage_bucket" "media_bucket" {
  project                     = var.gcp_project_id
  name                        = "${var.gcp_project_id}-surgicalm-media"
  location                    = "US"
  force_destroy               = false 
  uniform_bucket_level_access = true
}

