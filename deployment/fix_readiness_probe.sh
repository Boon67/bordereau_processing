#!/bin/bash

# Fix Readiness Probe Issue
# This script redeploys the backend with updated health checks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Fixing Backend Readiness Probe${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Load configuration
source "$SCRIPT_DIR/default.config"
if [ -f "$SCRIPT_DIR/custom.config" ]; then
    source "$SCRIPT_DIR/custom.config"
fi

# Check if we're using SPCS
if [ -z "$SERVICE_NAME" ]; then
    echo -e "${RED}Error: SERVICE_NAME not set in configuration${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking current service status${NC}"
snow spcs service status "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME" || true
echo ""

echo -e "${YELLOW}Step 2: Rebuilding backend image${NC}"
cd "$PROJECT_ROOT"

# Build backend image
echo "Building backend image..."
docker build -f docker/Dockerfile.backend -t backend:latest .

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build backend image${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Backend image built successfully${NC}"
echo ""

echo -e "${YELLOW}Step 3: Tagging and pushing to Snowflake${NC}"

# Get registry path
REGISTRY_PATH="$SNOWFLAKE_ACCOUNT.registry.snowflakecomputing.com/$DATABASE_NAME/$SCHEMA_NAME/$IMAGE_REPOSITORY"

# Tag image
docker tag backend:latest "$REGISTRY_PATH/backend:latest"

# Login to Snowflake registry
echo "Logging in to Snowflake registry..."
snow spcs image-registry login --connection "$SNOW_CONNECTION"

# Push image
echo "Pushing backend image to Snowflake..."
docker push "$REGISTRY_PATH/backend:latest"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to push backend image${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Backend image pushed successfully${NC}"
echo ""

echo -e "${YELLOW}Step 4: Updating service${NC}"

# Check if service exists
SERVICE_EXISTS=$(snow spcs service list --database "$DATABASE_NAME" --schema "$SCHEMA_NAME" --format json | jq -r ".[] | select(.name == \"$SERVICE_NAME\") | .name" || echo "")

if [ -z "$SERVICE_EXISTS" ]; then
    echo -e "${RED}Service $SERVICE_NAME does not exist${NC}"
    echo "Please run ./deploy.sh first to create the service"
    exit 1
fi

# Suspend service
echo "Suspending service..."
snow spcs service suspend "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME"

# Wait for suspension
echo "Waiting for service to suspend..."
sleep 10

# Resume service (this will pull the new image)
echo "Resuming service with new image..."
snow spcs service resume "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME"

echo -e "${GREEN}✓ Service updated${NC}"
echo ""

echo -e "${YELLOW}Step 5: Monitoring service startup${NC}"
echo "Waiting for service to start (this may take 1-2 minutes)..."
echo ""

# Monitor service status
MAX_WAIT=180  # 3 minutes
WAIT_INTERVAL=10
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    echo "Checking service status... (${ELAPSED}s elapsed)"
    
    STATUS=$(snow spcs service status "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME" --format json | jq -r '.[0].status' || echo "UNKNOWN")
    
    echo "Current status: $STATUS"
    
    if [ "$STATUS" = "READY" ]; then
        echo -e "${GREEN}✓ Service is READY!${NC}"
        break
    fi
    
    if [ "$STATUS" = "FAILED" ]; then
        echo -e "${RED}✗ Service failed to start${NC}"
        echo ""
        echo "Checking logs..."
        snow spcs service logs "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME" --container-name backend --num-lines 50
        exit 1
    fi
    
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${YELLOW}Warning: Service did not become ready within ${MAX_WAIT} seconds${NC}"
    echo "Current status:"
    snow spcs service status "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME"
    echo ""
    echo "Recent logs:"
    snow spcs service logs "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME" --container-name backend --num-lines 50
fi

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Testing Health Endpoints${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Get service endpoint
ENDPOINT=$(snow spcs service list --database "$DATABASE_NAME" --schema "$SCHEMA_NAME" --format json | jq -r ".[] | select(.name == \"$SERVICE_NAME\") | .dns_name" || echo "")

if [ -n "$ENDPOINT" ]; then
    echo "Service endpoint: https://$ENDPOINT"
    echo ""
    
    echo -e "${YELLOW}Testing /api/health (basic health check)${NC}"
    curl -s "https://$ENDPOINT/api/health" | jq . || echo "Failed to reach endpoint"
    echo ""
    
    echo -e "${YELLOW}Testing /api/health/db (database health check)${NC}"
    curl -s "https://$ENDPOINT/api/health/db" | jq . || echo "Failed to reach endpoint"
    echo ""
    
    echo -e "${YELLOW}Testing /api/health/ready (readiness check)${NC}"
    curl -s "https://$ENDPOINT/api/health/ready" | jq . || echo "Failed to reach endpoint"
    echo ""
else
    echo -e "${YELLOW}Could not determine service endpoint${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Readiness Probe Fix Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Next steps:"
echo "1. Check service status: ./manage_services.sh status"
echo "2. View logs: ./manage_services.sh logs backend 50"
echo "3. Test health endpoints:"
echo "   - Basic health: curl https://\$ENDPOINT/api/health"
echo "   - Database health: curl https://\$ENDPOINT/api/health/db"
echo "   - Readiness: curl https://\$ENDPOINT/api/health/ready"
echo ""
