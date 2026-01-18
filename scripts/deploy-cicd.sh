#!/bin/bash

# Victoria Fisheries Bot - CI/CD Pipeline Deployment Script
# This script automates the deployment of the CI/CD infrastructure

set -e

echo "================================================"
echo "Victoria Fisheries - CI/CD Pipeline Setup"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "ℹ $1"
}

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    print_error "Not in terraform directory. Please run from terraform/ directory."
    exit 1
fi

# Check prerequisites
echo "Checking prerequisites..."

# Check Terraform
if ! command -v terraform &> /dev/null; then
    print_error "Terraform not installed. Please install Terraform first."
    exit 1
fi
print_success "Terraform installed: $(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not installed. Please install AWS CLI first."
    exit 1
fi
print_success "AWS CLI installed: $(aws --version)"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Please run 'aws configure'."
    exit 1
fi
print_success "AWS credentials configured"

echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found"
    print_info "Creating from example..."
    
    if [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Please edit terraform.tfvars with your values before continuing"
        print_info "Required values:"
        echo "  - github_owner"
        echo "  - github_repo"
        echo "  - github_token"
        echo "  - github_webhook_secret"
        echo ""
        read -p "Press Enter after editing terraform.tfvars..."
    else
        print_error "terraform.tfvars.example not found. Please create terraform.tfvars manually."
        exit 1
    fi
fi

# Validate required variables are set
echo "Validating configuration..."
required_vars=("github_owner" "github_repo" "github_token" "github_webhook_secret")
missing_vars=()

for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}\s*=" terraform.tfvars; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    print_error "Missing required variables in terraform.tfvars:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    exit 1
fi
print_success "Configuration validated"

echo ""
echo "================================================"
echo "Deployment Plan"
echo "================================================"
echo ""
echo "This script will:"
echo "1. Initialize Terraform"
echo "2. Review deployment plan"
echo "3. Deploy CI/CD infrastructure"
echo "4. Display outputs"
echo ""
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    print_info "Deployment cancelled"
    exit 0
fi

echo ""
echo "================================================"
echo "Step 1: Initializing Terraform"
echo "================================================"
echo ""

terraform init
print_success "Terraform initialized"

echo ""
echo "================================================"
echo "Step 2: Reviewing Deployment Plan"
echo "================================================"
echo ""

if ! terraform plan -out=tfplan; then
    print_error "Terraform plan failed"
    exit 1
fi
print_success "Plan created successfully"

echo ""
read -p "Review the plan above. Continue with deployment? (yes/no): " confirm_plan

if [ "$confirm_plan" != "yes" ]; then
    print_info "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

echo ""
echo "================================================"
echo "Step 3: Deploying Infrastructure"
echo "================================================"
echo ""

if ! terraform apply tfplan; then
    print_error "Terraform apply failed"
    rm -f tfplan
    exit 1
fi

rm -f tfplan
print_success "Infrastructure deployed successfully!"

echo ""
echo "================================================"
echo "Step 4: Deployment Outputs"
echo "================================================"
echo ""

terraform output

echo ""
echo "================================================"
echo "Next Steps"
echo "================================================"
echo ""
echo "1. Add the following files to your GitHub repository:"
echo "   - buildspec.yml"
echo "   - appspec.yml"
echo "   - scripts/ directory (all .sh files)"
echo "   - test.js"
echo ""
echo "2. Ensure your server.js has a /health endpoint:"
echo "   app.get('/health', (req, res) => {"
echo "     res.status(200).json({ status: 'healthy' });"
echo "   });"
echo ""
echo "3. Push your code to trigger the pipeline:"
echo "   git add ."
echo "   git commit -m 'Add CI/CD configuration'"
echo "   git push origin main"
echo ""
echo "4. Monitor the pipeline:"
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
PIPELINE_NAME=$(terraform output -raw pipeline_name 2>/dev/null || echo "victoria-fisheries-bot-pipeline")
echo "   https://${REGION}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${PIPELINE_NAME}/view"
echo ""

# Store secrets in SSM Parameter Store (optional)
echo ""
read -p "Do you want to store secrets in AWS SSM Parameter Store? (yes/no): " store_secrets

if [ "$store_secrets" == "yes" ]; then
    echo ""
    echo "Storing secrets in SSM Parameter Store..."
    
    read -p "Enter WAHA API Key: " waha_key
    read -p "Enter Database Password: " db_password
    read -p "Enter Phone Number: " phone_number
    
    aws ssm put-parameter \
        --name "/victoria-fisheries/prod/waha-api-key" \
        --value "$waha_key" \
        --type "SecureString" \
        --overwrite || print_warning "Failed to store WAHA API Key"
    
    aws ssm put-parameter \
        --name "/victoria-fisheries/prod/database-password" \
        --value "$db_password" \
        --type "SecureString" \
        --overwrite || print_warning "Failed to store Database Password"
    
    aws ssm put-parameter \
        --name "/victoria-fisheries/prod/phone-number" \
        --value "$phone_number" \
        --type "String" \
        --overwrite || print_warning "Failed to store Phone Number"
    
    print_success "Secrets stored in SSM Parameter Store"
fi

echo ""
print_success "CI/CD Pipeline deployment complete!"
echo ""
