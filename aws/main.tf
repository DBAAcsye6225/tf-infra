# 1. Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# 2. Create Internet Gateway (IGW)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# 3. Create Public Subnets (3)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.public_subnet_az[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-${count.index + 1}"
  }
}

# 4. Create Private Subnets (3)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.private_subnet_az[count.index]

  tags = {
    Name = "${var.vpc_name}-private-${count.index + 1}"
  }
}

# 5. Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

# 6. Create Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Private RT does not route to IGW

  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}

# 7. Associate Public Subnets to Public Route Table
resource "aws_route_table_association" "public_assoc" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 8. Associate Private Subnets to Private Route Table
resource "aws_route_table_association" "private_assoc" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# 9. Data source to find the latest custom AMI
data "aws_ami" "webapp" {
  most_recent = true
  owners      = ["163285046203"] # Dev account - where images are built

  filter {
    name   = "name"
    values = ["csye6225-webapp-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# 10. Load Balancer Security Group
resource "aws_security_group" "load_balancer" {
  name        = "${var.vpc_name}-lb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.vpc_name}-lb-sg"
  }
}

# 11. Application Security Group
resource "aws_security_group" "application" {
  name        = "${var.vpc_name}-application-sg"
  description = "Security group for web application instances"
  vpc_id      = aws_vpc.main.id

  # Allow SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH"
  }

  # Allow app traffic ONLY from Load Balancer SG
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
    description     = "Allow app traffic from Load Balancer only"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.vpc_name}-application-sg"
  }
}

# 12. Application Load Balancer
resource "aws_lb" "webapp" {
  name               = "${var.vpc_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.vpc_name}-alb"
  }
}

# 13. Target Group
resource "aws_lb_target_group" "webapp" {
  name     = "${var.vpc_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 60
    matcher             = "200"
  }

  tags = {
    Name = "${var.vpc_name}-tg"
  }
}

# 14. Listener on port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.webapp.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp.arn
  }
}

# 15. Launch Template
resource "aws_launch_template" "webapp" {
  name          = "csye6225_asg"
  image_id      = data.aws_ami.webapp.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.application.id]
  }

  # Allow IMDSv1 for now (testing)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 25
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  # User data to inject database, S3 config, and CloudWatch Agent configuration
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Use IMDSv2 because instance metadata tokens are required.
    TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
    INSTANCE_ID=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || true)
    if [ -z "$INSTANCE_ID" ]; then
      INSTANCE_ID="unknown-instance"
    fi

    # Configure application environment variables
    echo "SPRING_DATASOURCE_URL=jdbc:mysql://${aws_db_instance.webapp.address}:3306/csye6225" >> /etc/environment
    echo "SPRING_DATASOURCE_USERNAME=csye6225" >> /etc/environment
    echo "SPRING_DATASOURCE_PASSWORD=${var.db_password}" >> /etc/environment
    echo "S3_BUCKET_NAME=${aws_s3_bucket.webapp.bucket}" >> /etc/environment
    echo "AWS_REGION=${var.aws_region}" >> /etc/environment
    echo "APP_LOG_PATH=/var/log/webapp/webapp.log" >> /etc/environment
    echo "SNS_TOPIC_ARN=${aws_sns_topic.user_verification.arn}" >> /etc/environment
    echo "JAVA_TOOL_OPTIONS=-Xms128m -Xmx384m" >> /etc/environment
    source /etc/environment

    # Create CloudWatch Agent configuration directory
    sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

    # Create CloudWatch Agent configuration file with instance ID
    sudo tee /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent-config.json > /dev/null <<CONFIG
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/webapp/webapp.log",
                "log_group_name": "/aws/ec2/webapp",
                "log_stream_name": "$INSTANCE_ID",
                "retention_in_days": 7
              }
            ]
          }
        }
      },
      "metrics": {
        "namespace": "CSYE6225",
        "metrics_collected": {
          "statsd": {
            "service_address": "127.0.0.1:8125",
            "metrics_collection_interval": 60,
            "metrics_aggregation_interval": 60
          }
        }
      }
    }
    CONFIG

    # Ensure webapp log directory exists
    sudo mkdir -p /var/log/webapp
    sudo chown csye6225:csye6225 /var/log/webapp

    # Install CloudWatch agent if it is not already present on the AMI.
    if [ ! -x /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
      wget -q https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
      sudo dpkg -i -E /tmp/amazon-cloudwatch-agent.deb || sudo apt-get -y -f install
      rm -f /tmp/amazon-cloudwatch-agent.deb
    fi

    # Start CloudWatch Agent
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent-config.json \
      -s

    # Wait for RDS to be ready
    sleep 30

    # Restart webapp service
    sudo systemctl restart webapp
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.vpc_name}-webapp-asg-instance"
    }
  }

  depends_on = [aws_db_instance.webapp]
}

# 16. Auto Scaling Group
resource "aws_autoscaling_group" "webapp" {
  name                      = "${var.vpc_name}-asg"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  default_cooldown          = var.asg_cooldown
  health_check_type         = "ELB"
  health_check_grace_period = 300
  vpc_zone_identifier       = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.webapp.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.webapp.arn]

  tag {
    key                 = "Name"
    value               = "${var.vpc_name}-webapp-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AutoScalingGroup"
    value               = "${var.vpc_name}-asg"
    propagate_at_launch = true
  }
}

# 17. Scale UP policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.vpc_name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.webapp.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = var.asg_cooldown
  policy_type            = "SimpleScaling"
}

# 18. Scale DOWN policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.vpc_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.webapp.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = var.asg_cooldown
  policy_type            = "SimpleScaling"
}

# 19. High CPU alarm (> 5%)
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.vpc_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "Scale up when CPU > 90% for 2 periods"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp.name
  }
}

# 20. Low CPU alarm (< 3%)
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.vpc_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_down_cpu_threshold
  alarm_description   = "Scale down when CPU < ${var.scale_down_cpu_threshold}%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp.name
  }
}

# Route 53 A record for app endpoint
resource "aws_route53_record" "app" {
  zone_id = var.route53_zone_id
  name    = "${var.subdomain_prefix}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.webapp.dns_name
    zone_id                = aws_lb.webapp.zone_id
    evaluate_target_health = true
  }
}

# ============================================================
# Assignment 05 Resources
# ============================================================

# 12. Generate UUID for S3 bucket name
resource "random_uuid" "s3_bucket_name" {}

# 13. S3 Bucket
resource "aws_s3_bucket" "webapp" {
  bucket        = random_uuid.s3_bucket_name.result
  force_destroy = true

  tags = {
    Name = "${var.vpc_name}-webapp-s3"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "webapp" {
  bucket = aws_s3_bucket.webapp.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Lifecycle Policy - transition to STANDARD_IA after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "webapp" {
  bucket = aws_s3_bucket.webapp.id

  rule {
    id     = "transition-to-standard-ia"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# Block all public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "webapp" {
  bucket = aws_s3_bucket.webapp.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 14. Database Security Group
resource "aws_security_group" "database" {
  name        = "${var.vpc_name}-database-sg"
  description = "Security group for RDS database instances"
  vpc_id      = aws_vpc.main.id

  # Allow MySQL traffic from application security group ONLY
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
    description     = "Allow MySQL from application SG"
  }

  tags = {
    Name = "${var.vpc_name}-database-sg"
  }
}

# 15. DB Subnet Group (uses private subnets)
resource "aws_db_subnet_group" "webapp" {
  name       = "${var.vpc_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.vpc_name}-db-subnet-group"
  }
}

# 16. RDS Parameter Group
resource "aws_db_parameter_group" "webapp" {
  name   = "${var.vpc_name}-db-params"
  family = "mysql8.0"

  tags = {
    Name = "${var.vpc_name}-db-params"
  }
}

# 17. RDS Instance
resource "aws_db_instance" "webapp" {
  identifier     = "csye6225"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = "csye6225"
  username = "csye6225"
  password = var.db_password

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true

  db_subnet_group_name   = aws_db_subnet_group.webapp.name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.webapp.name

  tags = {
    Name = "csye6225-rds"
  }
}

# 18. IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.vpc_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.vpc_name}-ec2-role"
  }
}

# IAM Policy for S3 access (least privilege)
resource "aws_iam_policy" "s3_access" {
  name        = "${var.vpc_name}-s3-access-policy"
  description = "Allow EC2 to access webapp S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.webapp.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.webapp.arn
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Attach AWS managed CloudWatch agent policy to EC2 role
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Allow EC2 instances to publish user verification messages to SNS
resource "aws_iam_role_policy" "ec2_sns_publish" {
  name = "ec2-sns-publish"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.user_verification.arn
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.vpc_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ============================================================
# Assignment 08 Resources
# ============================================================

resource "aws_dynamodb_table" "email_tracking" {
  name         = "csye6225-email-tracking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "${var.vpc_name}-email-tracking"
  }
}

resource "aws_sns_topic" "user_verification" {
  name = "csye6225-user-verification"

  tags = {
    Name = "${var.vpc_name}-user-verification"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.vpc_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.vpc_name}-lambda-exec-role"
  }
}

resource "aws_iam_role_policy" "lambda_logs" {
  name = "lambda-cloudwatch-logs"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda-dynamodb-email-tracking"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.email_tracking.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ses" {
  name = "lambda-ses-send-email"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "email_verification" {
  filename         = "/home/dbaa/serverless/target/serverless-1.0-SNAPSHOT.jar"
  source_code_hash = filebase64sha256("/home/dbaa/serverless/target/serverless-1.0-SNAPSHOT.jar")
  function_name    = "csye6225-email-verification"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "com.csye6225.serverless.EmailVerificationHandler::handleRequest"
  runtime          = "java17"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.email_tracking.name
      SES_SENDER_EMAIL    = "noreply@demo.dbaa.me"
      DOMAIN_NAME         = "${var.subdomain_prefix}.${var.domain_name}"
    }
  }

  tags = {
    Name = "${var.vpc_name}-email-verification"
  }
}

resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = aws_sns_topic.user_verification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.email_verification.arn
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_verification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.user_verification.arn
}
