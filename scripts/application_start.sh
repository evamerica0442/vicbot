#!/bin/bash
# CodeDeploy ApplicationStart Hook
# Starts the application after deployment

set -e

echo "================================================"
echo "ApplicationStart: Starting application"
echo "================================================"

# Create systemd service file if it doesn't exist
if [ ! -f /etc/systemd/system/victoria-bot.service ]; then
    echo "✓ Creating systemd service..."
    cat > /etc/systemd/system/victoria-bot.service << 'EOF'
[Unit]
Description=Victoria Fisheries WhatsApp Bot
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/victoria-fisheries-bot
Environment=NODE_ENV=production
EnvironmentFile=/opt/victoria-fisheries-bot/.env
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/victoria-fisheries/bot.log
StandardError=append:/var/log/victoria-fisheries/bot-error.log

# Security settings
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    
    echo "  Service file created"
    
    # Reload systemd to recognize new service
    systemctl daemon-reload
    
    # Enable service to start on boot
    systemctl enable victoria-bot
    echo "  Service enabled for auto-start"
fi

# Start the service
echo "✓ Starting victoria-bot service..."
systemctl start victoria-bot

# Wait for service to start
echo "✓ Waiting for service to initialize..."
sleep 5

# Check if service started successfully
if systemctl is-active --quiet victoria-bot; then
    echo "  ✓ Service started successfully"
    
    # Display service status
    systemctl status victoria-bot --no-pager || true
else
    echo "  ✗ ERROR: Service failed to start"
    echo ""
    echo "Service logs:"
    journalctl -u victoria-bot -n 50 --no-pager
    exit 1
fi

echo "================================================"
echo "ApplicationStart: Completed successfully"
echo "================================================"

exit 0
