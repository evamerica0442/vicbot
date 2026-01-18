#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable Docker service
systemctl enable docker
systemctl start docker

# Create directory for Waha data persistence
mkdir -p /opt/waha-data

# Pull and run Waha container
docker run -d \
  --name waha \
  --restart unless-stopped \
  -p 3000:3000 \
  -e WHATSAPP_API_KEY="${waha_api_key}" \
  -e WHATSAPP_API_PORT=3000 \
  -e WAHA_DASHBOARD_ENABLED=true \
  -e WAHA_DASHBOARD_USERNAME=admin \
  -e WAHA_DASHBOARD_PASSWORD="${waha_dashboard_password}" \
  -e WHATSAPP_SWAGGER_ENABLED=true \
  -e WHATSAPP_SWAGGER_USERNAME=admin \
  -e WHATSAPP_SWAGGER_PASSWORD="${waha_dashboard_password}" \
  -v /opt/waha-data:/app/.wwebjs_auth \
  devlikeapro/waha:latest

echo "Waha container started!"

# Wait for Waha to be ready
echo "Waiting for Waha to start..."
until curl -s http://localhost:3000/health > /dev/null 2>&1; do
  echo "Waha not ready, waiting..."
  sleep 5
done

echo "Waha is ready!"

# Create a monitoring script
cat > /usr/local/bin/check-waha.sh << 'MONEOF'
#!/bin/bash
if ! curl -s http://localhost:3000/health > /dev/null 2>&1; then
  echo "Waha is down, restarting..."
  docker restart waha
fi
MONEOF

chmod +x /usr/local/bin/check-waha.sh

# Add cron job for monitoring (every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check-waha.sh") | crontab -

echo "Waha setup complete!"
echo "Access Waha at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
