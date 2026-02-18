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
  owners      = ["self"] # AMIs owned by your account

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

  # Launch in first public subnet
  subnet_id = aws_subnet.public[0].id

  # Attach security group
  vpc_security_group_ids = [aws_security_group.application.id]

  # Disable detailed monitoring (additional cost)
  monitoring = false

  # Disable termination protection
  disable_api_termination = false

  # Root volume configuration
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 25
    delete_on_termination = true
  }

  tags = {
    Name = "${var.vpc_name}-webapp-instance"
  }
}
