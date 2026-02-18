variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-east1"
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_cidrs" {
  description = "List of CIDR blocks for subnets (3 public + 3 private)"
  type        = list(string)
  default = [
    "10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24", # Public
    "10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"  # Private
  ]
}

variable "machine_type" {
  description = "GCP machine type"
  type        = string
  default     = "e2-medium"
}

variable "instance_zone" {
  description = "Zone for the compute instance"
  type        = string
  default     = "us-east1-b"
}
