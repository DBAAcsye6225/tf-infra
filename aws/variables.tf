variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI Profile to use (dev or demo)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDRs for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDRs for private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "public_subnet_az" {
  description = "List of Availability Zones for public subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_az" {
  description = "List of Availability Zones for private subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path for the target group"
  type        = string
  default     = "/healthz"
}

variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 3
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 5
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 3
}

variable "asg_cooldown" {
  description = "Cooldown period in seconds"
  type        = number
  default     = 60
}

variable "scale_up_cpu_threshold" {
  description = "CPU threshold to trigger scale up"
  type        = number
  default     = 5
}

variable "scale_down_cpu_threshold" {
  description = "CPU threshold to trigger scale down"
  type        = number
  default     = 3
}

variable "db_password" {
  description = "Master password for RDS instance"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "domain_name" {
  description = "Root domain name (e.g., example.com)"
  type        = string
}

variable "subdomain_prefix" {
  description = "Subdomain prefix for this environment (e.g., dev or demo)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for the subdomain"
  type        = string
}