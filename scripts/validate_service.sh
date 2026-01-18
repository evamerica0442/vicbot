#!/bin/bash
# CodeDeploy ValidateService Hook
# Validates that the deployed application is working correctly

set -e

echo "================================================"
echo "ValidateService: Running health checks"
echo "================================================"

# Configuration
MAX_ATTEMPTS=15
ATTEMPT_INTERVAL=3
HEALTH_ENDPOINT="http://localhost:4000/health"

# Function to check service status
check_service_status() {
    if ! systemctl is-active --quiet victoria-bot; then
        echo "✗ Service is not running"
        return 1
    fi
    return 0
}

# Function to check port binding
check_port_binding() {
    if ! netstat -tuln 2>/dev/null | grep -q ":4000 " && ! ss -tuln 2>/dev/null | grep -q ":4000 "; then
        echo "✗ Port 4000 is not listening"
        return 1
    fi
    return 0
}

# Function to check HTTP health endpoint
check_health_endpoint() {
    local response
    response=$(curl -s -w "%{http_code}" -o /dev/null "$HEALTH_ENDPOINT" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        return 0
    else
        echo "✗ Health endpoint returned: $response"
        return 1
    fi
}

# Function to check process
check_process() {
    if ! pgrep -f "node.*server.js" > /dev/null; then
        echo "✗ Node process not found"
        return 1
    fi
    return 0
}

# Check 1: Service Status
echo "✓ Checking service status..."
if check_service_status; then
    echo "  ✓ Service is running"
else
    echo "  ✗ Service check failed"
    systemctl status victoria-bot --no-pager || true
    exit 1
fi

# Check 2: Process Running
echo "✓ Checking Node.js process..."
if check_process; then
    echo "  ✓ Process is running"
else
    echo "  ✗ Process check failed"
    exit 1
fi

# Check 3: Port Binding
echo "✓ Checking port binding..."
attempt=0
while [ $attempt -lt 5 ]; do
    if check_port_binding; then
        echo "  ✓ Port 4000 is listening"
        break
    fi
    attempt=$((attempt + 1))
    if [ $attempt -lt 5 ]; then
        sleep 2
    fi
done

if [ $attempt -eq 5 ]; then
    echo "  ✗ Port binding check failed"
    exit 1
fi

# Check 4: HTTP Health Endpoint
echo "✓ Checking HTTP health endpoint..."
attempt=0
success=false

while [ $attempt -lt $MAX_ATTEMPTS ]; do
    attempt=$((attempt + 1))
    echo "  Attempt $attempt/$MAX_ATTEMPTS..."
    
    if check_health_endpoint; then
        echo "  ✓ Health endpoint responding correctly"
        success=true
        break
    fi
    
    if [ $attempt -lt $MAX_ATTEMPTS ]; then
        echo "  Retrying in ${ATTEMPT_INTERVAL}s..."
        sleep $ATTEMPT_INTERVAL
    fi
done

if [ "$success" = false ]; then
    echo ""
    echo "✗ Health check failed after $MAX_ATTEMPTS attempts"
    echo ""
    echo "Recent application logs:"
    journalctl -u victoria-bot -n 30 --no-pager
    echo ""
    echo "Recent error logs:"
    tail -n 20 /var/log/victoria-fisheries/bot-error.log 2>/dev/null || echo "No error log found"
    exit 1
fi

# Check 5: Database Connectivity (optional)
# Uncomment if you want to verify database connection
# echo "✓ Checking database connectivity..."
# if curl -s -f http://localhost:4000/api/health/db > /dev/null 2>&1; then
#     echo "  ✓ Database connection OK"
# else
#     echo "  ⚠ Database check failed (may not be critical)"
# fi

# Check 6: Memory Usage
echo "✓ Checking resource usage..."
PID=$(pgrep -f "node.*server.js" | head -1)
if [ -n "$PID" ]; then
    MEM_USAGE=$(ps -p $PID -o %mem= | tr -d ' ')
    CPU_USAGE=$(ps -p $PID -o %cpu= | tr -d ' ')
    echo "  Memory usage: ${MEM_USAGE}%"
    echo "  CPU usage: ${CPU_USAGE}%"
fi

# All checks passed
echo ""
echo "================================================"
echo "✓ All validation checks passed!"
echo "================================================"
echo ""
echo "Application Details:"
echo "  Status: Running"
echo "  Port: 4000"
echo "  Health: OK"
echo "  Deployment: Successful"
echo ""

exit 0
