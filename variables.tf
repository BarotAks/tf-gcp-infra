variable "project_id" {
  description = "The ID of the GCP project"
}

variable "region" {
  description = "The region to deploy resources in"
  default     = "us-central1"
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