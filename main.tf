# Create a VPC
resource "google_compute_network" "my_vpc" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
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
# resource "google_compute_global_address" "gateway_ipv4" {
#   name         = var.internet_gateway_name
#   purpose      = "GATEWAY"
#   address_type = "EXTERNAL"
# }

# Create a route for webapp subnet
resource "google_compute_route" "webapp_route" {
  name             = var.webapp_route_name
  network          = google_compute_network.my_vpc.self_link
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}

# Create firewall rules
resource "google_compute_firewall" "allow_web_traffic" {
  name    = var.webapp_firewall_name
  network = google_compute_network.my_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = [var.application_port] # YOUR_APPLICATION_PORT with the port your application listens to
  }

  source_ranges = ["0.0.0.0/0"] # Allowing traffic from the internet
  target_tags   = ["web-server"]
}

# Create Compute Engine instance
resource "google_compute_instance" "my_instance" {
  name         = var.instance_name
  machine_type = var.machine_type # Default machine type
  zone         = var.zone
  tags         = ["web-server"]
  boot_disk {
    initialize_params {
      image = var.custom_image   # YOUR_CUSTOM_IMAGE with your custom image name or URL
      size  = var.size           # Size of the boot disk in GB
      type  = var.boot_disk_type # Type of the boot disk
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.webapp_subnet.self_link
    access_config {}
  }
}