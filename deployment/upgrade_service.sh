#!/bin/bash

# Upgrade Snowpark Container Service
# Uses snow spcs service upgrade command for seamless updates

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
echo -e "${BLUE}Upgrade Snowpark Container Service${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Default values
DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"
SCHEMA_NAME="PUBLIC"
SERVICE_NAME="BORDEREAU_APP"
SPEC_FILE="/tmp/bordereau_service_spec_fixed.yaml"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --database)
            DATABASE_NAME="$2"
            shift 2
            ;;
        --schema)
            SCHEMA_NAME="$2"
            shift 2
            ;;
        --service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --spec-file)
            SPEC_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --database NAME    Database name (default: BORDEREAU_PROCESSING_PIPELINE)"
            echo "  --schema NAME      Schema name (default: PUBLIC)"
            echo "  --service NAME     Service name (default: BORDEREAU_APP)"
            echo "  --spec-file PATH   Path to spec file (default: /tmp/bordereau_service_spec_fixed.yaml)"
            echo "  --help             Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}Configuration:${NC}"
echo "  Database: $DATABASE_NAME"
echo "  Schema: $SCHEMA_NAME"
echo "  Service: $SERVICE_NAME"
echo "  Spec File: $SPEC_FILE"
echo ""

# Check if spec file exists
if [ ! -f "$SPEC_FILE" ]; then
    echo -e "${RED}Error: Spec file not found: $SPEC_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking current service status${NC}"
snow spcs service status "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME" 2>&1 | head -20 || true
echo ""

echo -e "${YELLOW}Step 2: Suspending service${NC}"
snow spcs service suspend "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to suspend service${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Service suspended${NC}"
echo ""

echo -e "${YELLOW}Step 3: Waiting for suspension to complete${NC}"
sleep 10
echo -e "${GREEN}✓ Ready to upgrade${NC}"
echo ""

echo -e "${YELLOW}Step 4: Upgrading service with new specification${NC}"
snow spcs service upgrade "$SERVICE_NAME" \
    --spec-path "$SPEC_FILE" \
    --database "$DATABASE_NAME" \
    --schema "$SCHEMA_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to upgrade service${NC}"
    echo "Attempting to resume service..."
    snow spcs service resume "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME"
    exit 1
fi

echo -e "${GREEN}✓ Service upgraded${NC}"
echo ""

echo -e "${YELLOW}Step 5: Resuming service${NC}"
snow spcs service resume "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to resume service${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Service resumed${NC}"
echo ""

echo -e "${YELLOW}Step 6: Monitoring service startup${NC}"
echo "Waiting for service to start (this may take 1-2 minutes)..."
echo ""

# Monitor service status
MAX_WAIT=120  # 2 minutes
WAIT_INTERVAL=10
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    echo "Checking service status... (${ELAPSED}s elapsed)"
    
    STATUS=$(snow spcs service status "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME" 2>&1 | grep -E "backend.*READY" | wc -l || echo "0")
    
    if [ "$STATUS" -gt 0 ]; then
        echo -e "${GREEN}✓ Backend is READY!${NC}"
        break
    fi
    
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${YELLOW}Warning: Service did not become ready within ${MAX_WAIT} seconds${NC}"
    echo "Current status:"
    snow spcs service status "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME"
fi

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Final Service Status${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

snow spcs service status "$SERVICE_NAME" --database "$DATABASE_NAME" --schema "$SCHEMA_NAME"

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Service Upgrade Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Next steps:"
echo "1. Verify service status: snow spcs service status $SERVICE_NAME --database $DATABASE_NAME --schema $SCHEMA_NAME"
echo "2. Check logs: snow spcs service logs $SERVICE_NAME --database $DATABASE_NAME --schema $SCHEMA_NAME --container-name backend --instance-id 0 --num-lines 50"
echo "3. Test application endpoints"
echo ""
