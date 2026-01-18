# Victoria Fisheries - Terraform AWS Infrastructure

Infrastructure as Code for deploying the Victoria Fisheries WhatsApp ordering bot to AWS.

## Quick Start

```bash
# 1. Install prerequisites
# - Terraform: https://www.terraform.io/downloads
# - AWS CLI: https://aws.amazon.com/cli/

# 2. Configure AWS credentials
aws configure

# 3. Run the automated deployment
./deploy.sh
```

## What Gets Deployed

### Infrastructure Components

1. **VPC & Networking**
   - Custom VPC (10.0.0.0/16)
   - 2 public subnets across availability zones
   - Internet gateway and route tables

2. **EC2 Instances**
   - **Bot Server** (t3.small)
     - Node.js application
     - Express webhook server
     - Systemd service
   - **Waha Server** (t3.medium)
     - Docker container
     - WhatsApp HTTP API
     - Auto-restart on failure

3. **RDS PostgreSQL Database**
   - Instance: db.t3.micro
   - Storage: 20GB
   - Automated backups (7 days)
   - Private subnet access only

4. **Security Groups**
   - Bot: Port 4000 (webhook), SSH
   - Waha: Port 3000 (API), SSH
   - Database: Port 5432 (from bot only)

5. **IAM Roles**
   - EC2 instance profiles
   - SSM access for management

## File Structure

```
terraform/
├── main.tf                    # Main infrastructure definition
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example configuration
├── user-data-bot.sh          # Bot server initialization script
├── user-data-waha.sh         # Waha server initialization script
├── deploy.sh                  # Automated deployment script
├── DEPLOYMENT_GUIDE.md       # Comprehensive deployment guide
└── .gitignore                # Git ignore rules
```

## Manual Deployment Steps

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Required values:
- `key_pair_name` - Your AWS EC2 key pair name
- `waha_api_key` - Strong API key for Waha
- `db_password` - Strong database password

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review Plan

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

### 5. Get Outputs

```bash
terraform output
```

## Configuration Options

### Instance Sizing

Edit `terraform.tfvars`:

```hcl
# Smaller instances (save cost)
bot_instance_type  = "t3.micro"   # ~$7/month
waha_instance_type = "t3.small"   # ~$15/month
db_instance_class  = "db.t3.micro" # ~$15/month

# Larger instances (better performance)
bot_instance_type  = "t3.medium"  # ~$30/month
waha_instance_type = "t3.large"   # ~$60/month
db_instance_class  = "db.t3.small" # ~$30/month
```

### Region Selection

```hcl
aws_region = "us-east-1"  # N. Virginia (default)
# aws_region = "eu-west-1"  # Ireland
# aws_region = "ap-southeast-1"  # Singapore
```

### Security Hardening

```hcl
# Restrict SSH to your IP only
ssh_cidr_block = "1.2.3.4/32"  # Replace with your IP
```

## Post-Deployment

### Connect to Instances

```bash
# Bot server
ssh -i ~/.ssh/your-key.pem ubuntu@<BOT_IP>

# Waha server
ssh -i ~/.ssh/your-key.pem ubuntu@<WAHA_IP>
```

### Check Services

```bash
# Bot service status
sudo systemctl status victoria-bot

# Waha container status
sudo docker ps
sudo docker logs waha
```

### Configure WhatsApp

1. Open Waha dashboard: `http://<WAHA_IP>:3000`
2. Create session named "default"
3. Scan QR code with WhatsApp

### Test the Bot

Send a message to your WhatsApp number:
```
menu
```

## Monitoring

### View Logs

```bash
# Bot logs
ssh ubuntu@<BOT_IP>
sudo journalctl -u victoria-bot -f

# Waha logs
ssh ubuntu@<WAHA_IP>
sudo docker logs -f waha
```

### Check Orders

```bash
# Via API
curl http://<BOT_IP>:4000/orders

# Via database
ssh ubuntu@<BOT_IP>
PGPASSWORD=<PASSWORD> psql -h <DB_ENDPOINT> -U dbadmin -d victoriaorders
```

## Cost Breakdown

| Resource | Instance Type | Monthly Cost |
|----------|---------------|--------------|
| Bot EC2 | t3.small | $15 |
| Waha EC2 | t3.medium | $30 |
| RDS PostgreSQL | db.t3.micro | $15 |
| Data Transfer | ~10GB | $1 |
| Storage | 50GB | $5 |
| **Total** | | **~$66/month** |

### Cost Optimization

1. **Use Reserved Instances**: Save 40-60% with 1-3 year commitment
2. **Stop instances when not needed**: For development/testing
3. **Use Spot Instances**: Save up to 90% (not recommended for production)
4. **Optimize storage**: Delete old logs and unused snapshots

## Updating

### Update Bot Code

```bash
ssh ubuntu@<BOT_IP>
cd /opt/victoria-fisheries-bot
sudo nano server.js
sudo systemctl restart victoria-bot
```

### Update Infrastructure

1. Modify Terraform files
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes

### Update Waha

```bash
ssh ubuntu@<WAHA_IP>
sudo docker pull devlikeapro/waha:latest
sudo docker restart waha
```

## Backup

### Database Backups

Automated backups are enabled (7-day retention).

Manual backup:
```bash
aws rds create-db-snapshot \
  --db-instance-identifier victoria-fisheries-orders \
  --db-snapshot-identifier backup-$(date +%Y%m%d)
```

### Configuration Backup

```bash
# Save Terraform state
terraform state pull > backup-state.json

# Save tfvars
cp terraform.tfvars backup-tfvars.txt
```

## Disaster Recovery

### Restore Database

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier victoria-fisheries-orders-new \
  --db-snapshot-identifier backup-YYYYMMDD
```

### Rebuild Infrastructure

```bash
# If infrastructure is destroyed
terraform apply
```

## Cleanup

**⚠️ Warning: This will delete all resources including data!**

```bash
# Destroy all infrastructure
terraform destroy

# Confirm by typing: yes
```

Before destroying:
1. Backup database
2. Save configuration
3. Download logs
4. Disconnect WhatsApp

## Troubleshooting

### Common Issues

**Issue: `terraform init` fails**
```bash
# Solution: Clear cache
rm -rf .terraform
terraform init
```

**Issue: Can't connect to instances**
```bash
# Solution: Check security group allows your IP
# Update ssh_cidr_block in terraform.tfvars
terraform apply
```

**Issue: Bot not receiving messages**
```bash
# Check: Waha is running
ssh ubuntu@<WAHA_IP>
sudo docker ps

# Check: Webhook is configured
curl -H "X-Api-Key: YOUR_KEY" http://<WAHA_IP>:3000/api/webhooks

# Check: Bot service is running
ssh ubuntu@<BOT_IP>
sudo systemctl status victoria-bot
```

**Issue: Database connection failed**
```bash
# Check: Security group allows bot to access database
# Test connection
ssh ubuntu@<BOT_IP>
PGPASSWORD=<PASSWORD> psql -h <DB_ENDPOINT> -U dbadmin -d victoriaorders
```

## Advanced Configuration

### Custom Domain

1. Register domain in Route 53
2. Create SSL certificate in ACM
3. Add Application Load Balancer
4. Update DNS records

### Auto Scaling

1. Create Launch Template
2. Create Auto Scaling Group
3. Configure scaling policies
4. Add Load Balancer

### Multi-Region Deployment

1. Duplicate terraform configuration per region
2. Use Route 53 for failover
3. Set up cross-region database replication

## Support

- **Full Documentation**: See `DEPLOYMENT_GUIDE.md`
- **AWS Documentation**: https://docs.aws.amazon.com
- **Terraform Docs**: https://www.terraform.io/docs
- **Waha Docs**: https://waha.devlike.pro

## License

ISC
