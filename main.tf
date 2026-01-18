terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "victoria-fisheries-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "victoria-fisheries-igw"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "victoria-fisheries-public-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name        = "victoria-fisheries-public-2"
    Environment = var.environment
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "victoria-fisheries-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EC2 (Bot Server)
resource "aws_security_group" "bot_server" {
  name        = "victoria-fisheries-bot-sg"
  description = "Security group for bot server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "victoria-fisheries-bot-sg"
    Environment = var.environment
  }
}

# Security Group for Waha
resource "aws_security_group" "waha" {
  name        = "victoria-fisheries-waha-sg"
  description = "Security group for Waha container"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Waha API"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "victoria-fisheries-waha-sg"
    Environment = var.environment
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "victoria-fisheries-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from bot server"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bot_server.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "victoria-fisheries-rds-sg"
    Environment = var.environment
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "victoria-fisheries-ec2-role"

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
    Name        = "victoria-fisheries-ec2-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "victoria-fisheries-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance for Bot Server
resource "aws_instance" "bot_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bot_instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.bot_server.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/user-data-bot.sh", {
    waha_url        = "http://${aws_instance.waha.private_ip}:3000"
    waha_api_key    = var.waha_api_key
    waha_session    = var.waha_session
    db_host         = aws_db_instance.orders.address
    db_name         = aws_db_instance.orders.db_name
    db_user         = aws_db_instance.orders.username
    db_password     = var.db_password
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name        = "victoria-fisheries-bot"
    Environment = var.environment
  }
}

# EC2 Instance for Waha
resource "aws_instance" "waha" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.waha_instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.waha.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/user-data-waha.sh", {
    waha_api_key           = var.waha_api_key
    waha_dashboard_password = var.waha_dashboard_password
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name        = "victoria-fisheries-waha"
    Environment = var.environment
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "victoria-fisheries-db-subnet"
  subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name        = "victoria-fisheries-db-subnet"
    Environment = var.environment
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "orders" {
  identifier             = "victoria-fisheries-orders"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = "victoriaorders"
  username               = "dbadmin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  backup_retention_period = 0

  tags = {
    Name        = "victoria-fisheries-orders-db"
    Environment = var.environment
  }
}

# Data Sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Configure webhook after both instances are ready
resource "null_resource" "configure_webhook" {
  depends_on = [aws_instance.bot_server, aws_instance.waha]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting 60 seconds for services to start..."
      sleep 60
      echo "Configuring webhook..."
      curl -X POST http://${aws_instance.waha.public_ip}:3000/api/webhooks \
        -H "Content-Type: application/json" \
        -H "X-Api-Key: ${var.waha_api_key}" \
        -d '{
          "url": "http://${aws_instance.bot_server.private_ip}:4000/webhook",
          "events": ["message"],
          "session": "${var.waha_session}"
        }' || echo "Webhook configuration failed - configure manually"
    EOT
  }
}
