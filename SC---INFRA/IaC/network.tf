# Database VPC

resource "google_compute_network" "main_vpc" {
  name                    = "serverless-vpc"
  auto_create_subnetworks = false
  project                 = var.gcp_project_id
}

resource "google_compute_global_address" "private_ip_address" {
  project      = var.gcp_project_id
  name         = "private-ip-for-services"
  purpose      = "VPC_PEERING"
  address_type = "INTERNAL"
  prefix_length  = 16
  network      = google_compute_network.main_vpc.id
}

resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.main_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_vpc_access_connector" "serverless_connector" {
  project    = var.gcp_project_id
  name       = "serverless-connector"
  region     = var.gcp_region
  ip_cidr_range = "10.8.0.0/28"
  network    = google_compute_network.main_vpc.name
  depends_on = [google_service_networking_connection.default]
}