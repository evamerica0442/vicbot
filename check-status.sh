#!/bin/bash

# Victoria Fisheries - System Status Check Script

echo "🐟 Victoria Fisheries - System Status Check"
echo "==========================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get outputs from Terraform
echo "📊 Retrieving infrastructure details..."
BOT_IP=$(terraform output -raw bot_server_public_ip 2>/dev/null)
WAHA_IP=$(terraform output -raw waha_public_ip 2>/dev/null)
DB_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null)

if [ -z "$BOT_IP" ]; then
    echo -e "${RED}❌ Cannot retrieve Terraform outputs${NC}"
    echo "Run this script from the terraform directory after deployment"
    exit 1
fi

echo ""
echo "Infrastructure IPs:"
echo "  Bot Server:  $BOT_IP"
echo "  Waha Server: $WAHA_IP"
echo "  Database:    $DB_ENDPOINT"
echo ""

# Check Bot Server
echo "═══════════════════════════════════════"
echo "🤖 BOT SERVER HEALTH CHECK"
echo "═══════════════════════════════════════"

echo -n "Testing HTTP connection... "
if curl -s -o /dev/null -w "%{http_code}" http://$BOT_IP:4000/health | grep -q "200"; then
    echo -e "${GREEN}✓ ONLINE${NC}"
else
    echo -e "${RED}✗ OFFLINE${NC}"
fi

echo -n "Testing webhook endpoint... "
if curl -s -o /dev/null -w "%{http_code}" http://$BOT_IP:4000/webhook | grep -q "200\|405"; then
    echo -e "${GREEN}✓ ACCESSIBLE${NC}"
else
    echo -e "${RED}✗ NOT ACCESSIBLE${NC}"
fi

echo ""

# Check Waha Server
echo "═══════════════════════════════════════"
echo "📱 WAHA SERVER HEALTH CHECK"
echo "═══════════════════════════════════════"

echo -n "Testing HTTP connection... "
if curl -s -o /dev/null -w "%{http_code}" http://$WAHA_IP:3000/health | grep -q "200"; then
    echo -e "${GREEN}✓ ONLINE${NC}"
else
    echo -e "${RED}✗ OFFLINE${NC}"
fi

echo -n "Testing API endpoint... "
if curl -s http://$WAHA_IP:3000 | grep -q "waha\|api"; then
    echo -e "${GREEN}✓ API RESPONDING${NC}"
else
    echo -e "${YELLOW}? UNKNOWN STATUS${NC}"
fi

echo ""

# Check Database
echo "═══════════════════════════════════════"
echo "🗄️  DATABASE HEALTH CHECK"
echo "═══════════════════════════════════════"

DB_HOST=$(echo $DB_ENDPOINT | cut -d: -f1)
DB_PORT=$(echo $DB_ENDPOINT | cut -d: -f2)

echo -n "Testing database connectivity... "
if nc -z -w5 $DB_HOST $DB_PORT 2>/dev/null; then
    echo -e "${GREEN}✓ PORT OPEN${NC}"
else
    echo -e "${RED}✗ CANNOT CONNECT${NC}"
fi

echo ""

# Overall Status
echo "═══════════════════════════════════════"
echo "📋 QUICK DIAGNOSTIC COMMANDS"
echo "═══════════════════════════════════════"
echo ""
echo "View bot logs:"
echo "  ssh -i ~/.ssh/your-key.pem ubuntu@$BOT_IP"
echo "  sudo journalctl -u victoria-bot -f"
echo ""
echo "View Waha logs:"
echo "  ssh -i ~/.ssh/your-key.pem ubuntu@$WAHA_IP"
echo "  sudo docker logs -f waha"
echo ""
echo "Check orders:"
echo "  curl http://$BOT_IP:4000/orders"
echo ""
echo "Test WhatsApp:"
echo "  Send 'menu' to your connected WhatsApp number"
echo ""
echo "Access Waha dashboard:"
echo "  http://$WAHA_IP:3000"
echo ""

# Recommendations
echo "═══════════════════════════════════════"
echo "💡 RECOMMENDATIONS"
echo "═══════════════════════════════════════"
echo ""

# Check if services are down
if ! curl -s -o /dev/null http://$BOT_IP:4000/health; then
    echo -e "${YELLOW}⚠️  Bot server is down${NC}"
    echo "   Try: ssh ubuntu@$BOT_IP 'sudo systemctl restart victoria-bot'"
    echo ""
fi

if ! curl -s -o /dev/null http://$WAHA_IP:3000/health; then
    echo -e "${YELLOW}⚠️  Waha server is down${NC}"
    echo "   Try: ssh ubuntu@$WAHA_IP 'sudo docker restart waha'"
    echo ""
fi

echo "For detailed troubleshooting, see DEPLOYMENT_GUIDE.md"
echo ""
