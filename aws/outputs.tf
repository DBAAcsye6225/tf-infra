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

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.webapp.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.webapp.zone_id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.webapp.name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.webapp.arn
}

output "application_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.application.id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.webapp.bucket
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.webapp.endpoint
}

output "rds_address" {
  description = "RDS instance address (hostname only)"
  value       = aws_db_instance.webapp.address
}

output "iam_role_name" {
  description = "IAM role name for EC2"
  value       = aws_iam_role.ec2_role.name
}

output "app_domain_name" {
  description = "The domain name of the application"
  value       = aws_route53_record.app.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.user_verification.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.email_tracking.name
}

output "lambda_function_name" {
  value = aws_lambda_function.email_verification.function_name
}