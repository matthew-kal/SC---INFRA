# Global Variables

variable "gcp_project_id" {
  type        = string
  description = "The GCP project ID to deploy resources into."
}

variable "gcp_region" {
  type        = string
  description = "The GCP region for resources."
  default     = "us-east4" # N. Virginia
}