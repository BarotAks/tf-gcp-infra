# Create a VPC
resource "google_compute_network" "my_vpc" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true # Remove the default route after VPC creation
}

# Create a subnet for webapp
resource "google_compute_subnetwork" "webapp_subnet" {
  name                     = var.webapp_subnet_name
  region                   = var.region
  network                  = google_compute_network.my_vpc.self_link
  ip_cidr_range            = var.webapp_subnet_cidr
  depends_on               = [google_compute_network.my_vpc]
  private_ip_google_access = true
}

# Create a subnet for db
resource "google_compute_subnetwork" "db_subnet" {
  name                     = var.db_subnet_name
  region                   = var.region
  network                  = google_compute_network.my_vpc.self_link
  ip_cidr_range            = var.db_subnet_cidr
  depends_on               = [google_compute_network.my_vpc]
  private_ip_google_access = true
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


# # Create Compute Engine instance
# resource "google_compute_instance" "my_instance" {
#   name         = var.instance_name
#   machine_type = var.machine_type # Default machine type
#   zone         = var.zone
#   tags         = ["web-server"]
#   depends_on = [google_compute_subnetwork.webapp_subnet, google_compute_subnetwork.db_subnet,
#   google_service_networking_connection.private_access, google_service_account_key.my_service_account_key]
#   boot_disk {
#     initialize_params {
#       image = var.custom_image   # YOUR_CUSTOM_IMAGE with your custom image name or URL
#       size  = var.size           # Size of the boot disk in GB
#       type  = var.boot_disk_type # Type of the boot disk
#     }
#   }

#   network_interface {
#     subnetwork = google_compute_subnetwork.webapp_subnet.self_link
#     access_config {
#       nat_ip = google_compute_address.instance_ip.address
#     }
#   }

#   service_account {
#     email  = google_service_account.my_service_account.email
#     scopes = var.service_account_scopes
#   }

#   metadata_startup_script = <<-EOF
#     #!/bin/bash

#     # Database configuration
#     cat <<EOT >> /home/csye6225/webapp/.env
#     DB_HOST=${google_sql_database_instance.my_sql_instance.private_ip_address}
#     DB_USER=${google_sql_user.my_user.name}
#     DB_PASSWORD=${random_password.db_password.result}
#     DB_NAME=${google_sql_database.my_database.name}
#     PUBSUB_TOPIC=${google_pubsub_topic.verify_email_topic.name}
#     PROJECT_ID=${var.project_id}
#     EOT

#     # Ensure correct permissions for the .env file
#     sudo chmod 600 /home/csye6225/webapp/.env
#     sudo setenforce 0

#     # Restart the webapp service to apply the new database configuration
#     sudo systemctl stop webapp.service
#     sudo systemctl daemon-reload
#     sudo systemctl start webapp.service
#     sudo systemctl enable webapp.service
#   EOF
# }

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
    activation_policy = "ALWAYS"
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
  encryption_key_name = google_kms_crypto_key.sql_crypto_key.id
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

# # Create DNS Record Set for A record
# resource "google_dns_record_set" "a_record" {
#   name = var.domain_name
#   type = "A"
#   ttl  = 300
#   # managed_zone = google_dns_managed_zone.my_dns_zone.name
#   managed_zone = var.dns_zone_name
#   rrdatas      = [google_compute_address.instance_ip.address]
# }

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

# Create Pub/Sub Topic
resource "google_pubsub_topic" "verify_email_topic" {
  name = var.pubsub_topic_name
  labels = {
    retention_duration = "604800s" # 7 days in seconds
  }
}

# Create Pub/Sub Subscription
resource "google_pubsub_subscription" "verify_email_subscription" {
  name                 = var.subscription_name
  topic                = google_pubsub_topic.verify_email_topic.id
  ack_deadline_seconds = 10
}

# Create a Service Account for Cloud Functions
resource "google_service_account" "service-account-cf" {
  account_id   = var.service_account_cf_id
  display_name = "CSYE6225 Cloud functions Service Account"
}

# Create a Pub/Sub Topic IAM policy
resource "google_pubsub_topic_iam_policy" "topic_policy" {
  topic = google_pubsub_topic.verify_email_topic.name

  policy_data = jsonencode({
    bindings = [
      {
        role = "roles/pubsub.publisher"
        members = ["serviceAccount:${google_service_account.service-account-cf.email}",
        "serviceAccount:${google_service_account.my_service_account.email}"]
      },
    ]
  })
}

# Create a Pub/Sub Topic IAM binding
resource "google_pubsub_topic_iam_binding" "topic-binding" {
  project = google_pubsub_topic.verify_email_topic.project
  topic   = google_pubsub_topic.verify_email_topic.name
  role    = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${google_service_account.service-account-cf.email}",
    "serviceAccount:${google_service_account.my_service_account.email}"
  ]
}

# Create a Pub/Sub Topic IAM member
resource "google_pubsub_topic_iam_member" "topic-member" {
  project = google_pubsub_topic.verify_email_topic.project
  topic   = google_pubsub_topic.verify_email_topic.name
  role    = "roles/pubsub.admin"
  member  = "serviceAccount:${google_service_account.service-account-cf.email}"
}

# Create a Pub/Sub Subscription IAM policy
resource "google_pubsub_subscription_iam_policy" "subscription_policy" {
  subscription = google_pubsub_subscription.verify_email_subscription.name

  policy_data = jsonencode({
    bindings = [
      {
        role = "roles/pubsub.subscriber"
        members = ["serviceAccount:${google_service_account.service-account-cf.email}",
        "serviceAccount:${google_service_account.my_service_account.email}"]
      },
    ]
  })
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }
}

# Create a Pub/Sub Subscription IAM binding
resource "google_pubsub_subscription_iam_binding" "subscription-binding" {
  subscription = google_pubsub_subscription.verify_email_subscription.name
  role         = "roles/pubsub.subscriber"
  members = [
    "serviceAccount:${google_service_account.service-account-cf.email}",
    "serviceAccount:${google_service_account.my_service_account.email}"
  ]
}

# Create a Pub/Sub Subscription IAM member
resource "google_pubsub_subscription_iam_member" "subscription-iam" {
  subscription = google_pubsub_subscription.verify_email_subscription.name
  role         = "roles/pubsub.admin"
  member       = "serviceAccount:${google_service_account.service-account-cf.email}"
}

# Create IAM binding for Pub/Sub service account
resource "google_project_iam_binding" "pubsub_service_account_role" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:${google_service_account.my_service_account.email}"
  ]
}

# Create a Google Cloud Storage bucket for Cloud Function source code
resource "google_storage_bucket" "cloud_function_bucket" {
  name     = var.source_archive_bucket
  location = var.region
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage_crypto_key.id
  }
}

data "archive_file" "default" {
  type        = "zip"
  output_path = "./serverless.zip" # Use path.module to refer to the current directory
  source_dir  = "../serverless/"   # Use path.module as the source directory
}

resource "google_storage_bucket_object" "cloud-function-object" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.cloud_function_bucket.name
  source = data.archive_file.default.output_path # Path to the zipped function source code
}

# # Create a Serverless VPC Connector
# resource "google_compute_network" "serverless_connector_network" {
#   name                            = var.serverless_connector_network_name
#   auto_create_subnetworks         = false
#   routing_mode                    = var.routing_mode
#   delete_default_routes_on_create = true # Remove the default route after VPC creation
# }

# resource "google_compute_global_address" "serverless_connector_ip" {
#   name          = var.serverless_connector_ip_name
#   purpose       = var.purpose
#   address_type  = var.address_type
#   prefix_length = 16
#   network       = google_compute_network.serverless_connector_network.self_link
# }

resource "google_service_networking_connection" "serverless_connector_connection" {
  network                 = google_compute_network.my_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_access_range.name]
  lifecycle {
    prevent_destroy = false
  }
}

# Create a Serverless VPC Connector
resource "google_vpc_access_connector" "serverless_connector" {
  name           = var.serverless_connector_name
  network        = google_compute_network.my_vpc.id
  ip_cidr_range  = var.serverless_connector_ip
  min_throughput = 200
  max_throughput = 300
}

# Create Cloud Function to handle email verification
resource "google_cloudfunctions2_function" "cloud-function" {
  name        = "cloud-function"
  description = "Cloud Function to verify email addresses"
  location    = var.region

  build_config {
    runtime     = "nodejs16"
    entry_point = "helloPubSub"
    environment_variables = {
      MAILGUN_API_KEY = var.mailgun_api_key
      MAILGUN_DOMAIN  = var.mailgun_domain
      DB_HOST         = google_sql_database_instance.my_sql_instance.private_ip_address
      DB_USER         = google_sql_user.my_user.name
      DB_PASSWORD     = random_password.db_password.result
      DB_NAME         = google_sql_database.my_database.name
      PROJECT_ID      = var.project_id
      PUBSUB_TOPIC    = google_pubsub_topic.verify_email_topic.name
      LINK            = var.domain_name
    }
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_function_bucket.name
        object = google_storage_bucket_object.cloud-function-object.name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    vpc_connector      = google_vpc_access_connector.serverless_connector.name
    environment_variables = {
      SERVICE_CONFIG_TEST = "config_test"
      MAILGUN_API_KEY     = var.mailgun_api_key
      MAILGUN_DOMAIN      = var.mailgun_domain
      DB_HOST             = google_sql_database_instance.my_sql_instance.private_ip_address
      DB_USER             = google_sql_user.my_user.name
      DB_PASSWORD         = random_password.db_password.result
      DB_NAME             = google_sql_database.my_database.name
      PROJECT_ID          = var.project_id
      PUBSUB_TOPIC        = google_pubsub_topic.verify_email_topic.name
      LINK                = var.domain_name
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.my_service_account.email
  }
  # depends_on = [google_service_networking_connection.serverless_connector_connection]

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.verify_email_topic.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }

  depends_on = [google_service_networking_connection.serverless_connector_connection]
}

# # IAM Binding for Cloud Function
# resource "google_cloudfunctions2_function_iam_binding" "cloud-function_role" {
#   project        = var.project_id
#   location       = var.region
#   cloud_function = google_cloudfunctions2_function.cloud-function.name
#   role           = "roles/cloudfunctions.invoker"
#   members = [
#     "serviceAccount:${google_service_account.my_service_account.email}",
#   ]
# }

# Create a regional compute instance template
resource "google_compute_region_instance_template" "web_instance_template" {
  name  = var.instance_template_name
  region       = var.region
  machine_type = var.machine_type
  tags         = ["web-server"]
  depends_on = [google_compute_subnetwork.webapp_subnet, google_compute_subnetwork.db_subnet,
  google_service_networking_connection.private_access, google_service_account_key.my_service_account_key, google_kms_crypto_key.vm_crypto_key]

  disk {
    source_image = var.custom_image
    auto_delete  = true
    boot         = true
    type         = "BALANCED"
    disk_size_gb = var.size
    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.vm_crypto_key.id
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  network_interface {
    # network    = google_compute_network.my_vpc.self_link
    subnetwork = google_compute_subnetwork.webapp_subnet.self_link
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
    PUBSUB_TOPIC=${google_pubsub_topic.verify_email_topic.name}
    PROJECT_ID=${var.project_id}
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

# Create a compute health check
resource "google_compute_health_check" "webapp_health_check" {
  name                = var.health_check_name
  check_interval_sec  = 5  # Check the health every 10 seconds
  timeout_sec         = 5  # Timeout after 5 seconds
  healthy_threshold   = 2  # Mark as healthy after 2 successful checks
  unhealthy_threshold = 10 # Mark as unhealthy after 10 failed checks

  http_health_check {
    port_specification = "USE_FIXED_PORT"
    request_path       = "/healthz"   # Endpoint to check for health
    port               = var.app_port # Port where your web application is running
  }
}

# # Create a compute health check (regional)
# resource "google_compute_region_health_check" "webapp_health_check" {
#   name                = var.health_check_name
#   region              = var.region
#   check_interval_sec  = 10
#   timeout_sec         = 5
#   healthy_threshold   = 2
#   unhealthy_threshold = 10

#   http_health_check {
#     port         = 3000
#     request_path = "/healthz"
#   }
# }

# # Create a compute health check
# resource "google_compute_http_health_check" "webapp_health_check" {
#   name                = var.health_check_name
#   check_interval_sec  = 10
#   timeout_sec         = 5
#   healthy_threshold   = 2
#   unhealthy_threshold = 10

#   request_path = "/healthz"
#   # port         = var.app_port
#   port = 3000 # HTTPS port
# }


# Create a compute autoscaler
resource "google_compute_region_autoscaler" "webapp_autoscaler" {
  name   = var.autoscaler_name
  region = var.region
  target = google_compute_region_instance_group_manager.webapp_instance_group_manager.self_link
  autoscaling_policy {
    min_replicas    = 3
    max_replicas    = 6
    cooldown_period = 60
    cpu_utilization {
      target = 0.05
    }
  }
}

# # Create a compute autoscaler
# resource "google_compute_autoscaler" "web_autoscaler" {
#   name   = var.autoscaler_name
#   # zone   = var.zone
#   target = google_compute_region_instance_group_manager.web_instance_group_manager.self_link
#   autoscaling_policy {
#     min_replicas    = 1
#     max_replicas    = 10
#     cooldown_period = 60
#     cpu_utilization {
#       target = 0.05
#     }
#   }
# }

# resource "google_compute_target_pool" "web_target_pool" {
#   name          = "web-target-pool"
#   region        = var.region
#   health_checks = [google_compute_health_check.webapp_health_check.self_link]
# }


# Create a regional compute instance group manager
resource "google_compute_region_instance_group_manager" "webapp_instance_group_manager" {
  name               = var.instance_group_manager_name
  region             = var.region
  base_instance_name = var.base_instance_name
  target_size        = 1
  named_port {
    name = "http"
    port = var.app_port
  }
  # target_pools = [google_compute_target_pool.web_target_pool.self_link]
  version {
    instance_template = google_compute_region_instance_template.web_instance_template.self_link
  }
  auto_healing_policies {
    health_check      = google_compute_health_check.webapp_health_check.self_link
    initial_delay_sec = 60
  }
}

# # Update firewall rules to allow traffic from load balancer only
# resource "google_compute_firewall" "allow_lb_traffic" {
#   name    = "allow-lb-traffic"
#   network = google_compute_network.my_vpc.self_link

#   allow {
#     protocol = "tcp"
#     ports    = ["80", "443"]
#   }

#   source_ranges = [google_compute_global_forwarding_rule.lb_forwarding_rule.ip_address]
#   target_tags   = ["web-server"]
# }

# Update firewall rules to allow traffic from load balancer only
resource "google_compute_firewall" "allow_lb_traffic" {
  name    = "allow-lb-traffic"
  network = google_compute_network.my_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

# Create a reserved IP address for the load balancer
resource "google_compute_global_address" "lb_ip" {
  name = "lb-ip"
}

# Create an external Application Load Balancer
resource "google_compute_global_forwarding_rule" "lb_forwarding_rule" {
  name = "lb-forwarding-rule"
  # ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.lb_ip.address
  target                = google_compute_target_https_proxy.lb_http_proxy.self_link
  port_range            = "443"
}

resource "google_compute_target_https_proxy" "lb_http_proxy" {
  name             = "lb-http-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.lb_url_map.self_link
  ssl_certificates = [google_compute_ssl_certificate.ssl_certificate.id]
}

resource "google_compute_url_map" "lb_url_map" {
  name            = "lb-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.lb_backend_service.self_link
}

# resource "google_compute_backend_service" "lb_backend_service" {
#   name = "lb-backend-service"
#   backend {
#     group = google_compute_region_backend_service.lb_region_backend_service.self_link
#   }
#   load_balancing_scheme = "EXTERNAL"
# }

# resource "google_compute_region_backend_service" "lb_region_backend_service" {
#   name     = "lb-region-backend-service"
#   region   = var.region
#   project  = var.project_id
#   protocol = "HTTP"
#   port_name     = "http"
#   timeout_sec   = 300
#   health_checks = [google_compute_http_health_check.webapp_health_check.self_link]
#   backend {
#     group = google_compute_region_instance_group_manager.webapp_instance_group_manager.instance_group
#   }
# }

resource "google_compute_backend_service" "lb_backend_service" {
  name                  = "lb-backend-service"
  port_name             = "http"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 10
  backend {
    group = google_compute_region_instance_group_manager.webapp_instance_group_manager.instance_group
  }
  health_checks = [google_compute_health_check.webapp_health_check.self_link]
}

# Set up SSL certificates using Google-managed SSL certificates
resource "google_compute_ssl_certificate" "ssl_certificate" {
  name_prefix = "ssl-certificate-"
  private_key = file(var.private_key_path)
  certificate = file(var.certificate_path)

  lifecycle {
    create_before_destroy = true
  }
}

# Update the DNS record to point to the load balancer's IP address
resource "google_dns_record_set" "a_record" {
  name         = var.domain_name
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone_name
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

data "google_compute_default_service_account" "default" {
  provider = google
}

resource "google_kms_crypto_key_iam_binding" "sql_key_binding" {
  crypto_key_id = google_kms_crypto_key.sql_crypto_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members = [
    "serviceAccount:service-${var.project_number}@gcp-sa-cloud-sql.iam.gserviceaccount.com",
    # "serviceAccount:${google_service_account.my_service_account.email}",
  ]
}

resource "google_kms_crypto_key_iam_binding" "bucket_key_binding" {
  crypto_key_id = google_kms_crypto_key.storage_crypto_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members = [
    "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com",
    # "serviceAccount:${google_service_account.my_service_account.email}",
  ]
}

# resource "google_kms_crypto_key_iam_binding" "my_key_binding" {
#   crypto_key_id = google_kms_crypto_key.vm_crypto_key.id
#   role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
#   members = [
#     "serviceAccount:${google_service_account.my_service_account.email}",
#     "serviceAccount:service-${var.project_number}@gcp-sa-cloud-sql.iam.gserviceaccount.com",
#     "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com",
#     "serviceAccount:spring-outlet-406505@appspot.gserviceaccount.com",
#     "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"
#   ]
# }

resource "google_kms_crypto_key_iam_binding" "crypto_key" {
  crypto_key_id = google_kms_crypto_key.vm_crypto_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-${data.google_project.project.number}@compute-system.iam.gserviceaccount.com",
  ]
}

resource "google_project_iam_member" "kms_admin" {
  project = var.project_id
  role    = "roles/cloudkms.admin"
  member  = "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"
}

# resource "google_project_iam_member" "kms_admin2" {
#   project = var.project_id
#   role    = "roles/cloudkms.admin"
#   member  = "serviceAccount:${google_service_account.my_service_account.email}"
# }

resource "google_project_iam_binding" "token_creator_binding" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com",
  ]
}
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_service_identity" "cloudsql_service_account" {
  provider = google-beta

  project = var.project_id
  service = "sqladmin.googleapis.com"
}


resource "google_project_iam_binding" "service_account_roles_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  members = [
    "serviceAccount:${google_service_account.my_service_account.email}"
  ]
}

resource "google_project_iam_binding" "cloud_storage_roles_cloudkms" {
  project = var.project_id
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members = [
    "serviceAccount:${google_service_account.my_service_account.email}",
    "serviceAccount:${google_service_account.service-account-cf.email}"
  ]
}

# resource "google_project_iam_member" "storage_service_account_role" {
#   project = var.project_id
#   role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
#   member  = "serviceAccount:${google_service_account.my_service_account.email}"
# }


resource "random_id" "example_id" {
  byte_length = 8
}

# Create a key ring
resource "google_kms_key_ring" "my_key_ring" {
  name = "my-key-ring-${random_id.example_id.hex}"
  # name = "my-key-ring"
  location = var.region
}

# Create CKEM for Virtual Machines
resource "google_kms_crypto_key" "vm_crypto_key" {
  # name = "vm-crypto-key-${random_id.example_id.hex}"
  name     = "vm-crypto-key"
  key_ring = google_kms_key_ring.my_key_ring.id
  # key_ring        = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.key_ring}"
  rotation_period = "2592000s" # 30 days in seconds
}

# Create CKEM for CloudSQL instance
resource "google_kms_crypto_key" "sql_crypto_key" {
  # name = "sql-crypto-key-${random_id.example_id.hex}"
  name     = "sql-crypto-key"
  key_ring = google_kms_key_ring.my_key_ring.id
  # key_ring        = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.key_ring}"
  rotation_period = "2592000s" # 30 days in seconds
}

# Create CKEM for Cloud Storage
resource "google_kms_crypto_key" "storage_crypto_key" {
  # name = "storage-crypto-key-${random_id.example_id.hex}"
  name     = "storage-crypto-key"
  key_ring = google_kms_key_ring.my_key_ring.id
  # key_ring        = "projects/${var.project_id}/locations/${var.region}/keyRings/${var.key_ring}"
  rotation_period = "2592000s" # 30 days in seconds
}
