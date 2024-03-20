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

# Create firewall rule to deny all ingress traffic by default
resource "google_compute_firewall" "deny_all_traffic" {
  name    = var.deny_all_ingress
  network = google_compute_network.my_vpc.self_link

  # Deny all ingress traffic by default
  deny {
    protocol = "all" # deny all protocols
  }

  # Apply the firewall rule only to instances with the specified tags
  source_tags = ["web-server"]
}

# Create firewall rule to allow traffic on specific ports
resource "google_compute_firewall" "allow_web_traffic" {
  name    = var.webapp_firewall_name
  network = google_compute_network.my_vpc.self_link

  # Allow traffic on the specified ports
  allow {
    protocol = "tcp"
    ports    = var.application_port
  }

  # Apply the firewall rule only to instances with the specified tags
  # source_tags = ["web-server"]
  # target_tags = ["${google_sql_database_instance.my_sql_instance.name}-client"]

  source_ranges = ["0.0.0.0/0"] # Allowing traffic from the internet
  target_tags   = ["web-server"]
}


# Create Compute Engine instance
resource "google_compute_instance" "my_instance" {
  name         = var.instance_name
  machine_type = var.machine_type # Default machine type
  zone         = var.zone
  tags         = ["web-server"]
  depends_on = [google_compute_subnetwork.webapp_subnet, google_compute_subnetwork.db_subnet,
  google_service_networking_connection.private_access, google_service_account_key.my_service_account_key]
  boot_disk {
    initialize_params {
      image = var.custom_image   # YOUR_CUSTOM_IMAGE with your custom image name or URL
      size  = var.size           # Size of the boot disk in GB
      type  = var.boot_disk_type # Type of the boot disk
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.webapp_subnet.self_link
    access_config {
      nat_ip = google_compute_address.instance_ip.address
    }
  }

  service_account {
    email  = google_service_account.my_service_account.email
    scopes = var.service_account_scopes
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash

    # Database configuration
    cat <<EOT >> /home/csye6225/webapp/.env
    DB_HOST=${google_sql_database_instance.my_sql_instance.private_ip_address}
    DB_USER=${google_sql_user.my_user.name}
    DB_PASSWORD=${random_password.db_password.result}
    DB_NAME=${google_sql_database.my_database.name}
    EOT

    # Ensure correct permissions for the .env file
    sudo chmod 600 /home/csye6225/webapp/.env
    sudo setenforce 0

    # Restart the webapp service to apply the new database configuration
    sudo systemctl stop webapp.service
    sudo systemctl daemon-reload
    sudo systemctl start webapp.service
    sudo systemctl enable webapp.service
  EOF
}

resource "google_compute_address" "instance_ip" {
  name = "instance-ip"
}

# Enable private service access for the vpc
resource "google_compute_global_address" "private_access_range" {
  project       = google_compute_network.my_vpc.project
  name          = var.private_access_range_name
  purpose       = var.purpose
  address_type  = var.address_type
  network       = google_compute_network.my_vpc.self_link
  prefix_length = 16
}

# Create private services connection
resource "google_service_networking_connection" "private_access" {
  network                 = google_compute_network.my_vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_access_range.name]
  lifecycle {
    prevent_destroy = false
  }
}

# Create CloudSQL instance
resource "google_sql_database_instance" "my_sql_instance" {
  name                = var.sql_instance_name
  database_version    = var.sql_database_version
  region              = var.region
  deletion_protection = false
  depends_on          = [google_compute_subnetwork.db_subnet, google_service_networking_connection.private_access]
  settings {
    tier              = var.sql_tier
    disk_type         = var.sql_disk_type
    disk_size         = var.sql_disk_size
    availability_type = var.sql_availability_type
    # deletion_protection = false
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.my_vpc.self_link
      # enable_private_path_for_google_cloud_services = true
    }
    backup_configuration {
      enabled            = true
      binary_log_enabled = true # Enable binary logging
      # start_time         = "20:55"
    }
  }
}

# Create CloudSQL Database
resource "google_sql_database" "my_database" {
  name     = var.sql_database_name
  instance = google_sql_database_instance.my_sql_instance.name
}

# Create CloudSQL Database User
resource "google_sql_user" "my_user" {
  name     = var.sql_user_name
  instance = google_sql_database_instance.my_sql_instance.name
  password = random_password.db_password.result
}

# Generate random password
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


# Create Cloud DNS Managed Zone
# resource "google_dns_managed_zone" "my_dns_zone" {
#   name        = var.dns_zone_name
#   dns_name    = var.domain_name
#   description = "Managed zone for ${var.domain_name}"
# }

# Create DNS Record Set for A record
resource "google_dns_record_set" "a_record" {
  name = var.domain_name
  type = "A"
  ttl  = 300
  # managed_zone = google_dns_managed_zone.my_dns_zone.name
  managed_zone = var.dns_zone_name
  rrdatas      = [google_compute_address.instance_ip.address]
}

# Create a Service Account
resource "google_service_account" "my_service_account" {
  account_id   = var.service_account_id
  display_name = var.service_account_display_name
}

# Create a Service Account Key
resource "google_service_account_key" "my_service_account_key" {
  service_account_id = google_service_account.my_service_account.id
}

# Bind IAM roles to the Service Account
resource "google_project_iam_binding" "service_account_roles" {
  project = var.project_id
  role    = "roles/logging.admin"
  members = [
    "serviceAccount:${google_service_account.my_service_account.email}"
  ]
}

resource "google_project_iam_binding" "metric_writer_role" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  members = [
    "serviceAccount:${google_service_account.my_service_account.email}"
  ]
}