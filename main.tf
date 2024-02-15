# Create a VPC
resource "google_compute_network" "my_vpc" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true # Remove the default route after VPC creation
}

# Create a subnet for webapp
resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.webapp_subnet_name
  region        = var.region
  network       = google_compute_network.my_vpc.self_link
  ip_cidr_range = var.webapp_subnet_cidr
  depends_on    = [google_compute_network.my_vpc]
}

# Create a subnet for db
resource "google_compute_subnetwork" "db_subnet" {
  name          = var.db_subnet_name
  region        = var.region
  network       = google_compute_network.my_vpc.self_link
  ip_cidr_range = var.db_subnet_cidr
  depends_on    = [google_compute_network.my_vpc]
}

# Create an intenet gateway
resource "google_compute_global_address" "gateway_ipv4" {
  name         = var.internet_gateway_name
  purpose      = "GATEWAY"
  address_type = "EXTERNAL"
}

# Create a route for webapp subnet
resource "google_compute_route" "webapp_route" {
  name             = var.webapp_route_name
  network          = google_compute_network.my_vpc.self_link
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}
