#!/bin/bash

echo "🐟 Victoria Fisheries - AWS Deployment Quick Start"
echo "==================================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    echo "Install from: https://www.terraform.io/downloads"
    exit 1
fi

echo -e "${GREEN}✓ Terraform found: $(terraform version | head -n1)${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI found: $(aws --version)${NC}"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo -e "${GREEN}✓ AWS credentials configured${NC}"
echo ""

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
    echo -e "${YELLOW}⚠️  terraform.tfvars not found${NC}"
    echo ""
    read -p "Do you want to create it now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp terraform.tfvars.example terraform.tfvars
        echo -e "${GREEN}✓ Created terraform.tfvars${NC}"
        echo ""
        echo -e "${YELLOW}📝 Please edit terraform.tfvars and fill in:${NC}"
        echo "   - key_pair_name (your AWS EC2 key pair)"
        echo "   - waha_api_key (create a strong API key)"
        echo "   - db_password (create a strong password)"
        echo ""
        read -p "Press Enter when ready to continue..."
    else
        echo "Please create terraform.tfvars manually"
        exit 1
    fi
fi

echo -e "${GREEN}✓ terraform.tfvars exists${NC}"
echo ""

# Validate terraform.tfvars has required values
if grep -q "your-key-pair-name" terraform.tfvars; then
    echo -e "${RED}❌ Please update key_pair_name in terraform.tfvars${NC}"
    exit 1
fi

if grep -q "your-secure-api-key-here" terraform.tfvars; then
    echo -e "${RED}❌ Please update waha_api_key in terraform.tfvars${NC}"
    exit 1
fi

if grep -q "your-secure-db-password-here" terraform.tfvars; then
    echo -e "${RED}❌ Please update db_password in terraform.tfvars${NC}"
    exit 1
fi

echo -e "${GREEN}✓ terraform.tfvars looks good${NC}"
echo ""

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Terraform init failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Plan
echo "📋 Creating deployment plan..."
echo ""
terraform plan

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Terraform plan failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Plan created successfully${NC}"
echo ""

# Confirm deployment
echo -e "${YELLOW}⚠️  Ready to deploy to AWS${NC}"
echo ""
echo "This will create:"
echo "  • VPC and networking"
echo "  • 2 EC2 instances (Bot + Waha)"
echo "  • RDS PostgreSQL database"
echo "  • Security groups and IAM roles"
echo ""
echo "Estimated cost: ~$66/month"
echo ""
read -p "Do you want to proceed with deployment? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

# Apply
echo ""
echo "🚀 Deploying infrastructure..."
echo ""
terraform apply -auto-approve

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""

# Show outputs
echo "📊 Infrastructure Details:"
echo "=========================="
terraform output

echo ""
echo -e "${GREEN}🎉 Success!${NC}"
echo ""
echo "Next steps:"
echo "1. Open Waha dashboard: http://$(terraform output -raw waha_public_ip):3000"
echo "2. Connect WhatsApp by scanning QR code"
echo "3. Test the bot by sending 'menu' to your WhatsApp number"
echo ""
echo "For detailed instructions, see DEPLOYMENT_GUIDE.md"
echo ""
