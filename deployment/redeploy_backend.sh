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

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/default.config" 2>/dev/null || true
[ -f "$SCRIPT_DIR/custom.config" ] && source "$SCRIPT_DIR/custom.config"

SNOWFLAKE_CONNECTION="${SNOWFLAKE_CONNECTION:-}"
USE_DEFAULT_CONNECTION="${USE_DEFAULT_CONNECTION:-true}"
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
REPOSITORY_NAME="${REPOSITORY_NAME:-BORDEREAU_REPOSITORY}"
BACKEND_IMAGE_NAME="${BACKEND_IMAGE_NAME:-bordereau_backend}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
SCHEMA_NAME="${SCHEMA_NAME:-PUBLIC}"

# Get registry URL from snow CLI
REGISTRY_URL=$(snow spcs image-registry url --connection "${SNOWFLAKE_CONNECTION}" 2>/dev/null | grep -o '[^/]*\.snowflakecomputing\.com' || echo "registry.snowflakecomputing.com")

login_cmd="snow spcs image-registry login"
if [ -n "$SNOWFLAKE_CONNECTION" ]; then
    login_cmd="$login_cmd --connection $SNOWFLAKE_CONNECTION"
fi

$login_cmd

echo
echo -e "${YELLOW}[2/6]${NC} Building backend Docker image..."
docker build -f docker/Dockerfile.backend -t ${BACKEND_IMAGE_NAME}:${IMAGE_TAG} .

echo
echo -e "${YELLOW}[3/6]${NC} Tagging image for Snowflake registry..."
# Convert database name to lowercase for registry path
DB_LOWER=$(echo "$DATABASE_NAME" | tr '[:upper:]' '[:lower:]')
FULL_IMAGE_PATH="${REGISTRY_URL}/${DB_LOWER}/${SCHEMA_NAME,,}/${REPOSITORY_NAME,,}/${BACKEND_IMAGE_NAME}:${IMAGE_TAG}"
docker tag ${BACKEND_IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_PATH}

echo
echo -e "${YELLOW}[4/6]${NC} Pushing to Snowflake registry..."
docker push ${FULL_IMAGE_PATH}

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
