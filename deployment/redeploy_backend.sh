#!/bin/bash

# Redeploy Backend with Warehouse Fix
# This script rebuilds and redeploys the backend container

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🔧 Redeploying Backend with Warehouse Fix${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${YELLOW}[1/6]${NC} Logging into Snowflake image registry..."
snow spcs image-registry login --connection DEPLOYMENT

echo
echo -e "${YELLOW}[2/6]${NC} Building backend Docker image..."
docker build -f docker/Dockerfile.backend -t bordereau_backend:latest .

echo
echo -e "${YELLOW}[3/6]${NC} Tagging image for Snowflake registry..."
docker tag bordereau_backend:latest \
  sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:latest

echo
echo -e "${YELLOW}[4/6]${NC} Pushing to Snowflake registry..."
docker push sfsenorthamerica-tboon-aws2.registry.snowflakecomputing.com/bordereau_processing_pipeline/public/bordereau_repository/bordereau_backend:latest

echo
echo -e "${YELLOW}[5/6]${NC} Restarting backend service..."
cd deployment
./manage_services.sh restart-image backend

echo
echo -e "${YELLOW}[6/6]${NC} Waiting for service to restart (60 seconds)..."
sleep 60

echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ Backend Redeployed${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

echo -e "${BLUE}Checking logs for warehouse setup...${NC}"
./manage_services.sh logs backend 30 | grep -i warehouse || echo "No warehouse messages found yet"

echo
echo -e "${BLUE}Testing API endpoint...${NC}"
ENDPOINT="https://f2cmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app"
echo "Testing: $ENDPOINT/api/health"
curl -s "$ENDPOINT/api/health" | jq . || echo "Health check response"

echo
echo "Testing: $ENDPOINT/api/tpas"
curl -s "$ENDPOINT/api/tpas" | jq . || echo "TPAs response"

echo
echo -e "${GREEN}✅ Redeployment complete!${NC}"
echo
echo "If you still see errors, check logs with:"
echo "  ./manage_services.sh logs backend 100"
