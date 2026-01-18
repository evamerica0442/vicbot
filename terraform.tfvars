# AWS Configuration
aws_region = "us-east-1"  # Change to your preferred region
environment = "production"

# EC2 Instance Types
bot_instance_type   = "t3.small"   # Bot server - 2 vCPU, 2 GB RAM
waha_instance_type  = "c7i-flex.large"  # Waha server - 2 vCPU, 4 GB RAM (WhatsApp needs more memory)
db_instance_class   = "db.t3.micro" # RDS - 2 vCPU, 1 GB RAM

# SSH Access
key_pair_name    = "elmar-key"  # REQUIRED: Your AWS EC2 key pair name
ssh_cidr_block   = "0.0.0.0/0"          # Restrict to your IP for better security (e.g., "1.2.3.4/32")

# Waha Configuration
waha_api_key     = "5d24ef9266a345829c52a19d67a3b485"  # REQUIRED: Create a strong API key
waha_dashboard_password = "5d24ef9266a345829c52a19d67a3b485"  # REQUIRED: Create a strong dashboard password
waha_session     = "default"

# Database Configuration
db_password      = "5d24ef9266a345829c52a19d67a3b485"  # REQUIRED: Create a strong password

# Notes:
# 1. Copy this file to terraform.tfvars and fill in your values
# 2. Never commit terraform.tfvars to git (it's in .gitignore)
# 3. Generate strong passwords for waha_api_key and db_password
# 4. You must have an AWS EC2 key pair created before running terraform