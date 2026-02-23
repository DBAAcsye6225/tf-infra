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

# 10. Application Security Group
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

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  }

  # Allow HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS"
  }

  # Allow application port (8080)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow application traffic"
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

# 11. EC2 Instance
resource "aws_instance" "webapp" {
  ami           = data.aws_ami.webapp.id
  instance_type = var.instance_type
  key_name      = "aws-demo" # SSH key for debugging access

  # Launch in first public subnet
  subnet_id = aws_subnet.public[0].id

  # Attach security group
  vpc_security_group_ids = [aws_security_group.application.id]

  # IAM Instance Profile for S3 access
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # Disable detailed monitoring (additional cost)
  monitoring = false

  # Disable termination protection
  disable_api_termination = false

  # Allow IMDSv1 for now (testing)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Root volume configuration
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 25
    delete_on_termination = true
  }

  # User data to inject database and S3 config
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "SPRING_DATASOURCE_URL=jdbc:mysql://${aws_db_instance.webapp.address}:3306/csye6225" >> /etc/environment
    echo "SPRING_DATASOURCE_USERNAME=csye6225" >> /etc/environment
    echo "SPRING_DATASOURCE_PASSWORD=${var.db_password}" >> /etc/environment
    echo "S3_BUCKET_NAME=${aws_s3_bucket.webapp.bucket}" >> /etc/environment
    echo "AWS_REGION=${var.aws_region}" >> /etc/environment
    source /etc/environment
    systemctl restart webapp
  EOF
  )

  depends_on = [aws_db_instance.webapp]

  tags = {
    Name = "${var.vpc_name}-webapp-instance"
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

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.vpc_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
