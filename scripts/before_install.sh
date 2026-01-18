#!/bin/bash
# CodeDeploy BeforeInstall Hook
# Runs before installing the new application version

set -e

echo "================================================"
echo "BeforeInstall: Starting pre-installation tasks"
echo "================================================"

# Get current timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/victoria-fisheries-bot.backup.${TIMESTAMP}"

# Backup current version if it exists
if [ -d "/opt/victoria-fisheries-bot" ]; then
    echo "✓ Backing up current version..."
    cp -r /opt/victoria-fisheries-bot "$BACKUP_DIR"
    echo "  Backup created at: $BACKUP_DIR"
    
    # Keep only last 3 backups to save disk space
    echo "✓ Cleaning up old backups..."
    cd /opt
    ls -dt victoria-fisheries-bot.backup.* 2>/dev/null | tail -n +4 | xargs rm -rf
    echo "  Old backups cleaned"
else
    echo "✓ No existing installation found, skipping backup"
fi

# Ensure application directory exists with correct permissions
echo "✓ Preparing application directory..."
mkdir -p /opt/victoria-fisheries-bot
chown -R ubuntu:ubuntu /opt/victoria-fisheries-bot
echo "  Directory ready"

# Create log directory if it doesn't exist
echo "✓ Preparing log directory..."
mkdir -p /var/log/victoria-fisheries
chown -R ubuntu:ubuntu /var/log/victoria-fisheries
echo "  Log directory ready"

echo "================================================"
echo "BeforeInstall: Completed successfully"
echo "================================================"

exit 0
