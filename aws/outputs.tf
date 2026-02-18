output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.webapp.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.webapp.public_ip
}

output "application_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.application.id
}