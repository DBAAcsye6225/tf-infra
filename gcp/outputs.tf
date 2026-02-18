output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "vpc_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "subnet_names" {
  description = "Names of all subnets"
  value       = google_compute_subnetwork.subnets[*].name
}

output "subnet_cidrs" {
  description = "CIDR ranges of all subnets"
  value       = google_compute_subnetwork.subnets[*].ip_cidr_range
}

output "instance_name" {
  description = "Name of the compute instance"
  value       = google_compute_instance.webapp.name
}

output "instance_external_ip" {
  description = "External IP of the compute instance"
  value       = google_compute_instance.webapp.network_interface[0].access_config[0].nat_ip
}

output "instance_internal_ip" {
  description = "Internal IP of the compute instance"
  value       = google_compute_instance.webapp.network_interface[0].network_ip
}