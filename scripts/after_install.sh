#!/bin/bash
# CodeDeploy AfterInstall Hook
# Runs after installing the new application version

set -e

echo "================================================"
echo "AfterInstall: Starting post-installation tasks"
echo "================================================"

cd /opt/victoria-fisheries-bot

# Install production dependencies
echo "✓ Installing production dependencies..."
npm ci --production --quiet
echo "  Dependencies installed"

# Fetch secrets from AWS Systems Manager Parameter Store
echo "✓ Fetching configuration from AWS SSM..."

# Get AWS region from instance metadata
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
export AWS_DEFAULT_REGION=$AWS_REGION

# Fetch parameters (uncomment and modify based on your SSM setup)
# WAHA_API_KEY=$(aws ssm get-parameter --name "/victoria-fisheries/prod/waha-api-key" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
# DATABASE_PASSWORD=$(aws ssm get-parameter --name "/victoria-fisheries/prod/database-password" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
# PHONE_NUMBER=$(aws ssm get-parameter --name "/victoria-fisheries/prod/phone-number" --query 'Parameter.Value' --output text 2>/dev/null || echo "")

# For now, we'll use environment variables from the existing deployment
# Get private IP for Waha connection
WAHA_PRIVATE_IP=$(aws ec2 describe-instances \
  --region $AWS_REGION \
  --filters "Name=tag:Name,Values=Victoria Fisheries Waha Server" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text 2>/dev/null || echo "localhost")

# Get database endpoint
DB_ENDPOINT=$(aws rds describe-db-instances \
  --region $AWS_REGION \
  --db-instance-identifier victoria-fisheries-orders \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text 2>/dev/null || echo "localhost")

# Create .env file
echo "✓ Creating environment configuration..."
cat > .env << EOF
# Application Configuration
PORT=4000
NODE_ENV=production

# Waha Configuration
WAHA_URL=http://${WAHA_PRIVATE_IP}:3000
WAHA_API_KEY=\${WAHA_API_KEY:-${WAHA_API_KEY}}

# Database Configuration
DATABASE_URL=postgresql://dbadmin:\${DATABASE_PASSWORD}@${DB_ENDPOINT}:5432/victoriaorders

# Phone Configuration
PHONE_NUMBER=\${PHONE_NUMBER:-${PHONE_NUMBER}}

# Logging
LOG_LEVEL=info
EOF

# Set secure permissions on .env
chmod 600 .env
chown ubuntu:ubuntu .env
echo "  Configuration created"

# Run database migrations if needed
# echo "✓ Running database migrations..."
# npm run migrate || echo "  No migrations to run"

# Set proper ownership
echo "✓ Setting file permissions..."
chown -R ubuntu:ubuntu /opt/victoria-fisheries-bot
echo "  Permissions set"

echo "================================================"
echo "AfterInstall: Completed successfully"
echo "================================================"

exit 0
