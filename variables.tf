variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "bot_instance_type" {
  description = "EC2 instance type for bot server"
  type        = string
  default     = "t3.small"
}

variable "waha_instance_type" {
  description = "EC2 instance type for Waha"
  type        = string
  default     = "t3.medium"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "key_pair_name" {
  description = "Name of the SSH key pair to use for EC2 instances"
  type        = string
}

variable "ssh_cidr_block" {
  description = "CIDR block allowed to SSH into instances"
  type        = string
  default     = "0.0.0.0/0"
}

variable "waha_api_key" {
  description = "API key for Waha authentication"
  type        = string
  sensitive   = true
}

variable "waha_dashboard_password" {
  description = "Password for Waha dashboard and Swagger UI"
  type        = string
  sensitive   = true
  default     = "VictoriaFish2024!"
}

variable "waha_session" {
  description = "Waha session name"
  type        = string
  default     = "default"
}

variable "db_password" {
  description = "Password for RDS database"
  type        = string
  sensitive   = true
}
