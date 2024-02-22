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
  default     = "3000"
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