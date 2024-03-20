variable "project_id" {
  description = "The ID of the GCP project"
}

variable "region" {
  description = "The region to deploy resources in"
  default     = "us-central1"
}

variable "routing_mode" {
  description = "The routing mode for the VPC"
  default     = "REGIONAL"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = "my-vpc"
}

variable "webapp_subnet_name" {
  description = "Name of the webapp subnet"
  default     = "webapp"
}

variable "db_subnet_name" {
  description = "Name of the db subnet"
  default     = "db"
}

variable "webapp_subnet_cidr" {
  description = "CIDR range for the webapp subnet"
  default     = "10.0.1.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR range for the db subnet"
  default     = "10.0.2.0/24"
}

variable "internet_gateway_name" {
  description = "Name of the internet gateway"
  default     = "my-gateway"
}
variable "webapp_route_name" {
  description = "Name of the route for the webapp subnet"
  default     = "webapp-route"
}

variable "zone" {
  description = "The zone to deploy resources in"
  default     = "us-central1-a"
}

variable "webapp_firewall_name" {
  description = "Name of the firewall rule for the webapp"
  default     = "webapp-firewall"
}

variable "application_port" {
  description = "The port the application listens to"
  type        = list(string)
  default     = ["3000"] # Default port for your application
}

variable "instance_name" {
  description = "Name of the instance"
  default     = "webapp-instance"
}

variable "machine_type" {
  description = "Machine type for the instance"
  default     = "n1-standard-1"
}

variable "custom_image" {
  description = "Custom image for the instance"
}

variable "size" {
  description = "Size of the boot disk in GB"
  default     = "100"
}

variable "boot_disk_type" {
  description = "Type of the boot disk"
  default     = "pd-balanced"
}

variable "private_access_range_name" {
  description = "Name of the private access range"
  default     = "my-private-range"
}

variable "purpose" {
  description = "Purpose of the private access range"
  default     = "VPC_PEERING"
}

variable "address_type" {
  description = "Type of the private access range"
  default     = "INTERNAL"
}

variable "sql_instance_name" {
  description = "The name of the Cloud SQL instance"
}

variable "sql_database_version" {
  description = "The version of the Cloud SQL database"
}

variable "sql_tier" {
  description = "The tier of the Cloud SQL instance"
}

variable "sql_disk_type" {
  description = "The disk type of the Cloud SQL instance"
}

variable "sql_disk_size" {
  description = "The disk size of the Cloud SQL instance"
}

variable "sql_availability_type" {
  description = "The availability type of the Cloud SQL instance"
}

variable "sql_database_name" {
  description = "The name of the Cloud SQL database"
}

variable "sql_user_name" {
  description = "The name of the Cloud SQL user"
}

variable "deny_all_ingress" {
  description = "Deny all ingress traffic"
}

variable "dns_zone_name" {
  description = "The name of the DNS zone"
}

variable "domain_name" {
  description = "The domain name"
}

variable "service_account_id" {
  description = "The service account ID"

}

variable "service_account_display_name" {
  description = "The display name for the service account"
}

variable "service_account_scopes" {
  description = "The scopes for the service account"
  type        = list(string)
  default     = ["cloud-platform"]
}