# Victoria Fisheries AWS Deployment Checklist

Use this checklist to ensure a smooth deployment to AWS.

## Pre-Deployment Checklist

### 1. Prerequisites Installed

- [ ] Terraform installed and working (`terraform --version`)
- [ ] AWS CLI installed and working (`aws --version`)
- [ ] Git installed (optional, for version control)

### 2. AWS Account Setup

- [ ] AWS account created
- [ ] AWS credentials configured (`aws configure`)
- [ ] IAM user has necessary permissions:
  - [ ] EC2 full access
  - [ ] VPC full access
  - [ ] RDS full access
  - [ ] IAM limited access
- [ ] AWS CLI can authenticate (`aws sts get-caller-identity`)

### 3. SSH Key Pair

- [ ] EC2 key pair created in AWS console or via CLI
- [ ] Private key (.pem file) saved to `~/.ssh/`
- [ ] Key permissions set correctly (`chmod 400 ~/.ssh/your-key.pem`)
- [ ] Key pair name noted for terraform.tfvars

### 4. Configuration Files

- [ ] `terraform.tfvars` created from example
- [ ] `key_pair_name` set in terraform.tfvars
- [ ] Strong `waha_api_key` generated (16+ characters)
- [ ] Strong `db_password` generated (16+ characters, mixed case, numbers, symbols)
- [ ] `aws_region` selected (default: us-east-1)
- [ ] `ssh_cidr_block` set (recommend: your IP/32 for security)

### 5. Cost Understanding

- [ ] Reviewed monthly cost estimate (~$66/month)
- [ ] AWS billing alerts configured
- [ ] Budget set in AWS console
- [ ] Understand how to check costs (`aws ce get-cost-and-usage`)

## Deployment Checklist

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

- [ ] Terraform initialized successfully
- [ ] No errors in output
- [ ] AWS provider downloaded

### 2. Review Plan

```bash
terraform plan
```

- [ ] Plan completes without errors
- [ ] Review resources to be created (~20 resources)
- [ ] Verify instance types and sizes
- [ ] Confirm regions and availability zones

### 3. Deploy Infrastructure

```bash
terraform apply
```

- [ ] Type "yes" to confirm
- [ ] Wait 10-15 minutes for deployment
- [ ] No errors during deployment
- [ ] All resources created successfully

### 4. Save Outputs

```bash
terraform output > outputs.txt
```

- [ ] Bot server public IP saved
- [ ] Waha server public IP saved
- [ ] Database endpoint saved
- [ ] SSH commands saved

## Post-Deployment Checklist

### 1. Verify Infrastructure

- [ ] Both EC2 instances show "running" in AWS console
- [ ] RDS instance shows "available" in AWS console
- [ ] Security groups created
- [ ] VPC and subnets created

### 2. Test Connectivity

```bash
# Bot server
curl http://<BOT_IP>:4000/health

# Waha server
curl http://<WAHA_IP>:3000/health
```

- [ ] Bot server responds with 200 OK
- [ ] Waha server responds with 200 OK
- [ ] Can SSH into bot server
- [ ] Can SSH into Waha server

### 3. Configure Waha

- [ ] Open Waha dashboard: `http://<WAHA_IP>:3000`
- [ ] Create session named "default"
- [ ] Scan QR code with WhatsApp
- [ ] Session shows "WORKING" status
- [ ] Test sending message from Waha dashboard

### 4. Configure Webhook

```bash
# Check if webhook is auto-configured
curl -H "X-Api-Key: YOUR_API_KEY" http://<WAHA_IP>:3000/api/webhooks
```

- [ ] Webhook registered and points to bot server
- [ ] Webhook URL is bot's private IP (not public)
- [ ] Webhook events include "message"

If not configured:
- [ ] Manually configure webhook using curl command
- [ ] Verify webhook registration
- [ ] Check bot logs for incoming webhooks

### 5. Test Bot Functionality

#### Basic Tests:
- [ ] Send "menu" → bot responds with menu
- [ ] Send "hi" → bot responds with menu
- [ ] Send "#01 #07" → bot shows order summary
- [ ] Provide delivery address → bot confirms order

#### Advanced Tests:
- [ ] Check order in database: `curl http://<BOT_IP>:4000/orders`
- [ ] Verify order format and data
- [ ] Test multiple orders
- [ ] Test invalid item numbers
- [ ] Test conversation flow restart

### 6. Verify Logging

```bash
# Bot logs
ssh ubuntu@<BOT_IP>
sudo journalctl -u victoria-bot -f

# Waha logs
ssh ubuntu@<WAHA_IP>
sudo docker logs -f waha
```

- [ ] Bot logs show startup messages
- [ ] Bot logs show incoming webhook requests
- [ ] Waha logs show WhatsApp connection
- [ ] No critical errors in logs

### 7. Database Verification

```bash
ssh ubuntu@<BOT_IP>
PGPASSWORD=<PASSWORD> psql -h <DB_ENDPOINT> -U dbadmin -d victoriaorders
```

- [ ] Can connect to database
- [ ] Orders table exists
- [ ] Test order is recorded
- [ ] Data format is correct

### 8. Security Check

- [ ] SSH only accessible from your IP (or as configured)
- [ ] Database only accessible from bot server
- [ ] No unnecessary ports open
- [ ] Strong passwords used
- [ ] API key is strong and secret

### 9. Monitoring Setup

- [ ] CloudWatch logs enabled
- [ ] Set up billing alerts
- [ ] Configure SNS notifications (optional)
- [ ] Add health check monitoring (optional)

## Operational Checklist

### Daily Operations

- [ ] Check bot logs for errors
- [ ] Monitor order volume
- [ ] Respond to any customer issues

### Weekly Operations

- [ ] Review AWS costs
- [ ] Check disk space usage
- [ ] Review error logs
- [ ] Verify backups are running

### Monthly Operations

- [ ] Apply security patches
- [ ] Update packages
- [ ] Review and optimize costs
- [ ] Database maintenance
- [ ] Review and rotate API keys

## Troubleshooting Checklist

### Bot Not Responding

- [ ] Check bot service status: `sudo systemctl status victoria-bot`
- [ ] Check bot logs: `sudo journalctl -u victoria-bot -f`
- [ ] Verify bot can reach database
- [ ] Restart bot service: `sudo systemctl restart victoria-bot`

### Waha Not Working

- [ ] Check Docker container: `sudo docker ps`
- [ ] Check Waha logs: `sudo docker logs waha`
- [ ] Verify WhatsApp connection in dashboard
- [ ] Restart container: `sudo docker restart waha`

### Webhook Issues

- [ ] Verify webhook is registered
- [ ] Check webhook URL uses private IP
- [ ] Test bot webhook endpoint
- [ ] Verify security groups allow traffic
- [ ] Check Waha can reach bot server

### Database Issues

- [ ] Verify RDS instance is running
- [ ] Check security group allows bot access
- [ ] Test connection from bot server
- [ ] Verify credentials are correct
- [ ] Check for connection errors in bot logs

### Performance Issues

- [ ] Check CPU usage: `top` or CloudWatch
- [ ] Check memory usage: `free -h` or CloudWatch
- [ ] Check disk space: `df -h`
- [ ] Review slow query logs
- [ ] Consider scaling up instances

## Backup and Recovery Checklist

### Before Making Changes

- [ ] Take manual database snapshot
- [ ] Save current terraform.tfvars
- [ ] Document current configuration
- [ ] Test restore procedure

### Regular Backups

- [ ] Verify automated RDS backups are running
- [ ] Test database restore process
- [ ] Backup Waha session data
- [ ] Backup configuration files

### Disaster Recovery

- [ ] Have restore procedures documented
- [ ] Know how to restore from snapshot
- [ ] Have emergency contact information
- [ ] Test recovery process quarterly

## Cleanup Checklist (When Decommissioning)

- [ ] Backup all important data
- [ ] Export order history
- [ ] Save configuration files
- [ ] Disconnect WhatsApp session
- [ ] Take final database snapshot
- [ ] Run `terraform destroy`
- [ ] Verify all resources deleted
- [ ] Check for any lingering costs
- [ ] Delete manual snapshots if not needed
- [ ] Remove DNS records if configured

## Success Criteria

Your deployment is successful when:

✅ Both EC2 instances are running
✅ Database is accessible
✅ WhatsApp is connected to Waha
✅ Bot responds to "menu" message
✅ Orders are recorded in database
✅ No errors in logs
✅ All services auto-restart on failure
✅ Backups are configured
✅ Monitoring is in place

## Support Resources

- 📖 **Full Documentation**: DEPLOYMENT_GUIDE.md
- 🔧 **Terraform Docs**: https://www.terraform.io/docs
- ☁️ **AWS Docs**: https://docs.aws.amazon.com
- 📱 **Waha Docs**: https://waha.devlike.pro
- 🐛 **Troubleshooting Script**: `./check-status.sh`

## Notes

Use this space to record your specific configuration details:

```
AWS Region: _________________
Key Pair Name: _________________
Bot Server IP: _________________
Waha Server IP: _________________
Database Endpoint: _________________
WhatsApp Number: _________________
Deployment Date: _________________
```

---

**Remember:** Always test in a development environment before deploying to production!
