#!/bin/bash
# CodeDeploy ApplicationStop Hook
# Stops the running application before deploying new version

set -e

echo "================================================"
echo "ApplicationStop: Stopping application"
echo "================================================"

# Check if service exists and is running
if systemctl list-units --full -all | grep -q 'victoria-bot.service'; then
    if systemctl is-active --quiet victoria-bot; then
        echo "✓ Stopping victoria-bot service..."
        systemctl stop victoria-bot
        
        # Wait for service to fully stop
        sleep 2
        
        # Verify service is stopped
        if systemctl is-active --quiet victoria-bot; then
            echo "✗ ERROR: Service failed to stop"
            exit 1
        fi
        
        echo "  Service stopped successfully"
    else
        echo "✓ Service already stopped"
    fi
else
    echo "✓ Service does not exist yet (first deployment)"
fi

# Kill any remaining node processes for this app (safety measure)
if pgrep -f "node.*server.js" > /dev/null; then
    echo "✓ Cleaning up stray processes..."
    pkill -f "node.*server.js" || true
    sleep 1
    echo "  Processes cleaned"
fi

echo "================================================"
echo "ApplicationStop: Completed successfully"
echo "================================================"

exit 0
