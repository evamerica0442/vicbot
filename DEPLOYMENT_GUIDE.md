# Victoria Fisheries - AWS Deployment Guide

Complete step-by-step guide to deploy the WhatsApp bot to AWS using Terraform.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                         AWS VPC                          │
│                                                          │
│  ┌──────────────┐         ┌──────────────┐             │
│  │   Waha EC2   │         │   Bot EC2    │             │
│  │  (t3.medium) │◄────────┤  (t3.small)  │             │
│  │  Port: 3000  │         │  Port: 4000  │             │
│  └──────────────┘         └──────┬───────┘             │
│                                   │                      │
│                                   │                      │
│                          ┌────────▼────────┐            │
│                          │  RDS PostgreSQL │            │
│                          │  (db.t3.micro)  │            │
│                          └─────────────────┘            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. Install Required Tools

#### Terraform
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify
terraform --version
```

#### AWS CLI
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
```

### 2. Configure AWS Credentials

```bash
aws configure
```

You'll need:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

### 3. Create EC2 Key Pair

```bash
# Create a new key pair in AWS
aws ec2 create-key-pair \
  --key-name victoria-fisheries-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/victoria-fisheries-key.pem

# Set correct permissions
chmod 400 ~/.ssh/victoria-fisheries-key.pem
```

Or create via AWS Console:
1. Go to EC2 → Key Pairs
2. Click "Create key pair"
3. Name: `victoria-fisheries-key`
4. Save the `.pem` file to `~/.ssh/`

## Step-by-Step Deployment

### Step 1: Prepare Configuration

```bash
# Navigate to terraform directory
cd terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Required values in terraform.tfvars:**
```hcl
key_pair_name    = "victoria-fisheries-key"  # Your key pair name
waha_api_key     = "VF-2024-SecureKey123"    # Create a strong API key
db_password      = "SecureDBPassword456!"     # Create a strong DB password
```

**Optional customization:**
```hcl
aws_region          = "eu-west-1"      # Change region if needed
bot_instance_type   = "t3.micro"       # Smaller/larger instance
waha_instance_type  = "t3.large"       # More memory for Waha
ssh_cidr_block      = "YOUR_IP/32"     # Restrict SSH to your IP
```

### Step 2: Initialize Terraform

```bash
terraform init
```

This will:
- Download AWS provider
- Initialize backend
- Prepare modules

### Step 3: Review the Plan

```bash
terraform plan
```

Review the resources that will be created:
- ✅ VPC with subnets
- ✅ Security groups
- ✅ 2 EC2 instances (Waha + Bot)
- ✅ RDS PostgreSQL database
- ✅ IAM roles

**Expected output:**
```
Plan: 20 to add, 0 to change, 0 to destroy.
```

### Step 4: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**Deployment takes approximately 10-15 minutes.**

### Step 5: Get Output Information

```bash
terraform output
```

**Save these values:**
```
bot_server_public_ip  = "54.123.45.67"
waha_public_ip        = "54.123.45.68"
waha_url             = "http://54.123.45.68:3000"
database_endpoint     = "victoria-fisheries-orders.xxx.us-east-1.rds.amazonaws.com:5432"
ssh_command_bot       = "ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@54.123.45.67"
ssh_command_waha      = "ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@54.123.45.68"
```

## Post-Deployment Configuration

### Step 1: Check Waha Status

```bash
# SSH into Waha server
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<WAHA_PUBLIC_IP>

# Check Docker container
sudo docker ps
sudo docker logs waha

# Test Waha API
curl http://localhost:3000/health
```

### Step 2: Connect WhatsApp to Waha

1. **Open Waha in browser:**
   ```
   http://<WAHA_PUBLIC_IP>:3000
   ```

2. **Create a session:**
   - Click "Add Session"
   - Session name: `default`
   - Scan QR code with WhatsApp

3. **Verify connection:**
   ```bash
   curl -H "X-Api-Key: YOUR_API_KEY" http://<WAHA_PUBLIC_IP>:3000/api/sessions
   ```

### Step 3: Configure Webhook

The webhook should be auto-configured, but verify:

```bash
# SSH into bot server
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<BOT_PUBLIC_IP>

# Check bot service status
sudo systemctl status victoria-bot

# View logs
sudo journalctl -u victoria-bot -f

# Test webhook registration
curl -H "X-Api-Key: YOUR_API_KEY" \
  http://<WAHA_PUBLIC_IP>:3000/api/webhooks
```

If webhook is not configured, set it up manually:

```bash
# From your local machine
curl -X POST http://<WAHA_PUBLIC_IP>:3000/api/webhooks \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -d '{
    "url": "http://<BOT_PRIVATE_IP>:4000/webhook",
    "events": ["message"],
    "session": "default"
  }'
```

### Step 4: Test the Bot

1. **Send a test message to your WhatsApp number:**
   ```
   menu
   ```

2. **Check bot logs:**
   ```bash
   ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<BOT_PUBLIC_IP>
   sudo journalctl -u victoria-bot -f
   ```

3. **Place a test order:**
   ```
   #01 #07
   123 Test Street, Grabouw
   ```

4. **Verify database:**
   ```bash
   # On bot server
   curl http://localhost:4000/orders
   ```

## Monitoring and Management

### View Logs

**Bot server logs:**
```bash
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<BOT_PUBLIC_IP>
sudo journalctl -u victoria-bot -f
```

**Waha logs:**
```bash
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<WAHA_PUBLIC_IP>
sudo docker logs -f waha
```

### Restart Services

**Restart bot:**
```bash
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<BOT_PUBLIC_IP>
sudo systemctl restart victoria-bot
```

**Restart Waha:**
```bash
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<WAHA_PUBLIC_IP>
sudo docker restart waha
```

### View Orders

```bash
# Via API
curl http://<BOT_PUBLIC_IP>:4000/orders

# Via database
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<BOT_PUBLIC_IP>
PGPASSWORD=<DB_PASSWORD> psql -h <DB_ENDPOINT> -U dbadmin -d victoriaorders
SELECT * FROM orders;
```

## Security Hardening

### 1. Restrict SSH Access

Edit `terraform.tfvars`:
```hcl
ssh_cidr_block = "YOUR_PUBLIC_IP/32"
```

Then apply:
```bash
terraform apply
```

### 2. Enable SSL/TLS

For production, set up:
- Application Load Balancer
- ACM SSL certificate
- HTTPS endpoints

### 3. Database Encryption

The RDS instance has encryption at rest enabled by default.

### 4. Rotate API Keys

Periodically change:
- Waha API key
- Database password

## Cost Estimation

**Monthly AWS costs (approximate):**

| Resource | Type | Monthly Cost |
|----------|------|--------------|
| Bot EC2 | t3.small | ~$15 |
| Waha EC2 | t3.medium | ~$30 |
| RDS | db.t3.micro | ~$15 |
| Data Transfer | 10GB | ~$1 |
| EBS Storage | 50GB | ~$5 |
| **Total** | | **~$66/month** |

### Cost Optimization Tips:

1. **Use Reserved Instances** (40-60% savings for 1-3 year commitment)
2. **Stop instances when not needed** (non-production)
3. **Use t3 burstable instances** (already configured)
4. **Enable S3 lifecycle policies** for logs

## Backup and Recovery

### Database Backups

RDS automated backups are enabled (7-day retention).

**Manual backup:**
```bash
aws rds create-db-snapshot \
  --db-instance-identifier victoria-fisheries-orders \
  --db-snapshot-identifier victoria-backup-$(date +%Y%m%d)
```

### Restore from Backup

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier victoria-fisheries-orders-restored \
  --db-snapshot-identifier victoria-backup-YYYYMMDD
```

## Troubleshooting

### Issue: Can't SSH into instances

**Solution:**
```bash
# Check security group allows your IP
aws ec2 describe-security-groups \
  --group-ids <SECURITY_GROUP_ID>

# Update terraform.tfvars with your IP
ssh_cidr_block = "$(curl -s ifconfig.me)/32"
terraform apply
```

### Issue: Bot not receiving messages

**Check:**
1. Waha is running: `sudo docker ps`
2. WhatsApp is connected in Waha dashboard
3. Webhook is configured: Check Waha logs
4. Bot service is running: `sudo systemctl status victoria-bot`
5. Network connectivity between instances

### Issue: Database connection failed

**Check:**
1. Database is running: AWS RDS Console
2. Security group allows bot server
3. Credentials are correct in bot's .env

**Test connection:**
```bash
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<BOT_PUBLIC_IP>
PGPASSWORD=<PASSWORD> psql -h <DB_ENDPOINT> -U dbadmin -d victoriaorders -c "\dt"
```

### Issue: High costs

**Monitor:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

**Optimize:**
- Stop instances during off-hours
- Reduce instance sizes
- Use spot instances for testing

## Updating the Application

### Update Bot Code

```bash
# SSH into bot server
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<BOT_PUBLIC_IP>

# Navigate to app directory
cd /opt/victoria-fisheries-bot

# Make changes to files
sudo nano server.js

# Restart service
sudo systemctl restart victoria-bot
```

### Update Waha

```bash
# SSH into Waha server
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<WAHA_PUBLIC_IP>

# Pull latest image
sudo docker pull devlikeapro/waha:latest

# Restart container
sudo docker restart waha
```

## Scaling Considerations

### Vertical Scaling (More Power)

Edit `terraform.tfvars`:
```hcl
bot_instance_type  = "t3.large"   # More CPU/RAM
waha_instance_type = "t3.xlarge"
db_instance_class  = "db.t3.small"
```

Apply changes:
```bash
terraform apply
```

### Horizontal Scaling (More Instances)

For high traffic:
- Add Application Load Balancer
- Create Auto Scaling Groups
- Use ElastiCache for session storage
- Migrate to Lambda for bot logic

## Cleanup / Destroy Infrastructure

**⚠️ WARNING: This will delete all resources including the database!**

```bash
# Destroy all resources
terraform destroy

# Confirm by typing: yes
```

**Before destroying:**
1. Backup database
2. Save important data
3. Download logs
4. Disconnect WhatsApp

## Support and Maintenance

### Regular Tasks

**Daily:**
- Monitor logs for errors
- Check order volume

**Weekly:**
- Review AWS costs
- Update packages if needed
- Verify backups

**Monthly:**
- Security patches
- Database optimization
- Cost analysis

### Getting Help

- **AWS Documentation:** https://docs.aws.amazon.com
- **Terraform Documentation:** https://www.terraform.io/docs
- **Waha Documentation:** https://waha.devlike.pro

## Next Steps

1. ✅ Set up domain name (optional)
2. ✅ Configure SSL/HTTPS (optional)
3. ✅ Set up monitoring (CloudWatch)
4. ✅ Create admin dashboard
5. ✅ Implement order notifications

---

## Quick Reference Commands

```bash
# Deploy
terraform init
terraform plan
terraform apply

# Check status
terraform output
ssh -i ~/.ssh/victoria-fisheries-key.pem ubuntu@<IP>

# View logs
sudo journalctl -u victoria-bot -f
sudo docker logs -f waha

# Restart services
sudo systemctl restart victoria-bot
sudo docker restart waha

# Destroy
terraform destroy
```

**🎉 Your Victoria Fisheries WhatsApp bot is now live on AWS!**
