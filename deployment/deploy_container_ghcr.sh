#!/bin/bash
# ============================================
# DEPLOY TO SNOWFLAKE USING GITHUB CONTAINER REGISTRY IMAGES
# ============================================
# Purpose: Deploy pre-built images from GHCR to Snowpark Container Services
# Usage: ./deploy_container_ghcr.sh [connection_name] [github_username] [version]
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to print header
print_header() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     SNOWFLAKE CONTAINER DEPLOYMENT (GHCR)                 ║"
    echo "║     Using Pre-built Images from GitHub                    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
}

print_header

# Check prerequisites
echo -e "${CYAN}Checking prerequisites...${NC}"
echo ""

MISSING_DEPS=false

# Check if snow CLI is installed
if ! command -v snow &> /dev/null; then
    echo -e "${RED}✗ Snowflake CLI (snow) is not installed${NC}"
    echo "  Install: pip install snowflake-cli-labs"
    MISSING_DEPS=true
else
    echo -e "${GREEN}✓ Snowflake CLI is installed${NC}"
fi

# Check if jq is installed (optional but recommended)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠ jq is not installed (optional, but recommended for JSON parsing)${NC}"
    echo "  Install: brew install jq (macOS) or apt-get install jq (Linux)"
else
    echo -e "${GREEN}✓ jq is installed${NC}"
fi

# Check if docker is installed (optional, for image verification)
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠ Docker is not installed (optional, only needed for local image verification)${NC}"
    echo "  Install: https://www.docker.com/products/docker-desktop"
else
    echo -e "${GREEN}✓ Docker is installed${NC}"
fi

echo ""

if [[ "$MISSING_DEPS" == "true" ]]; then
    echo -e "${RED}✗ Missing required dependencies. Please install them and try again.${NC}"
    exit 1
fi

# Get parameters
CONNECTION_NAME="${1:-}"
GITHUB_USERNAME="${2:-}"
VERSION="${3:-latest}"

# Load configuration
if [[ -f "${SCRIPT_DIR}/default.config" ]]; then
    source "${SCRIPT_DIR}/default.config"
fi

if [[ -f "${SCRIPT_DIR}/custom.config" ]]; then
    source "${SCRIPT_DIR}/custom.config"
fi

# Get connection name
if [[ -z "$CONNECTION_NAME" ]]; then
    echo -e "${CYAN}Available Snowflake Connections:${NC}"
    echo ""
    snow connection list 2>&1 || echo -e "${YELLOW}(Could not list connections)${NC}"
    echo ""
    read -p "Connection name: " CONNECTION_NAME
    
    if [[ -z "$CONNECTION_NAME" ]]; then
        echo -e "${RED}✗ Connection name is required${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Using connection: ${CONNECTION_NAME}${NC}"

# Get GitHub username
if [[ -z "$GITHUB_USERNAME" ]]; then
    echo ""
    read -p "GitHub username (for ghcr.io/USERNAME/bordereau): " GITHUB_USERNAME
    
    if [[ -z "$GITHUB_USERNAME" ]]; then
        echo -e "${RED}✗ GitHub username is required${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Using GitHub username: ${GITHUB_USERNAME}${NC}"
echo -e "${GREEN}✓ Using version: ${VERSION}${NC}"

# Set image URLs
FRONTEND_IMAGE="ghcr.io/${GITHUB_USERNAME}/bordereau/frontend:${VERSION}"
BACKEND_IMAGE="ghcr.io/${GITHUB_USERNAME}/bordereau/backend:${VERSION}"

echo ""
echo -e "${CYAN}Images to deploy:${NC}"
echo -e "  Frontend: ${FRONTEND_IMAGE}"
echo -e "  Backend:  ${BACKEND_IMAGE}"
echo ""

# Configuration (with defaults from config files)
DATABASE="${DATABASE_NAME:-FILE_PROCESSING_PIPELINE}"
WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
COMPUTE_POOL="${COMPUTE_POOL_NAME:-BORDEREAU_COMPUTE_POOL}"
SERVICE_NAME="${SERVICE_NAME:-BORDEREAU_APP}"
IMAGE_REPO="${REPOSITORY_NAME:-BORDEREAU_REPOSITORY}"
SCHEMA="${SCHEMA_NAME:-PUBLIC}"

echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}DEPLOYMENT CONFIGURATION${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Connection:     ${CYAN}$CONNECTION_NAME${NC}"
echo -e "  Database:       ${CYAN}$DATABASE${NC}"
echo -e "  Schema:         ${CYAN}$SCHEMA${NC}"
echo -e "  Warehouse:      ${CYAN}$WAREHOUSE${NC}"
echo -e "  Compute Pool:   ${CYAN}$COMPUTE_POOL${NC}"
echo -e "  Service Name:   ${CYAN}$SERVICE_NAME${NC}"
echo -e "  Image Repo:     ${CYAN}$IMAGE_REPO${NC}"
echo -e "  GitHub User:    ${CYAN}$GITHUB_USERNAME${NC}"
echo -e "  Version:        ${CYAN}$VERSION${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Confirm deployment
if [[ "${AUTO_APPROVE}" != "true" ]]; then
    read -p "Continue with deployment? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
    echo ""
fi

START_TIME=$(date +%s)

# Step 1: Check if Snowpark Container Services is available
echo -e "${CYAN}[1/6] Checking Snowpark Container Services availability...${NC}"
echo ""

# Check if we can list compute pools (basic SPCS check)
echo "Testing SPCS commands..."
COMPUTE_POOL_CHECK=$(snow sql --connection "$CONNECTION_NAME" -q "
USE ROLE ${SNOWFLAKE_ROLE};
SHOW COMPUTE POOLS;
" 2>&1)

EXIT_CODE=$?

# Debug output
if [[ $EXIT_CODE -ne 0 ]]; then
    echo ""
    echo "Command output:"
    echo "$COMPUTE_POOL_CHECK"
    echo ""
fi

# Check for SPCS availability
if echo "$COMPUTE_POOL_CHECK" | grep -qi "Unknown command\|does not exist\|not supported\|SQL compilation error\|invalid"; then
    echo -e "${RED}✗ Snowpark Container Services is NOT available${NC}"
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  SNOWPARK CONTAINER SERVICES NOT ENABLED                  ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Your Snowflake account does not have Snowpark Container"
    echo "Services (SPCS) enabled. This feature is required to deploy"
    echo "containers to Snowflake."
    echo ""
    echo -e "${YELLOW}To enable SPCS:${NC}"
    echo "  1. Contact your Snowflake account administrator"
    echo "  2. Or submit a support ticket to Snowflake"
    echo "  3. Request 'Snowpark Container Services' to be enabled"
    echo ""
    echo -e "${YELLOW}Requirements:${NC}"
    echo "  - Snowflake Enterprise Edition or higher"
    echo "  - Available on AWS, Azure, and GCP"
    echo "  - Must be enabled at the account level"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}ALTERNATIVE: Deploy Locally with Docker${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "You can run the application on your local machine:"
    echo ""
    echo "  cd deployment"
    echo "  ./deploy_local_ghcr.sh ${GITHUB_USERNAME} ${VERSION}"
    echo ""
    echo "This will:"
    echo "  ✓ Pull images from GitHub Container Registry"
    echo "  ✓ Run containers locally on your Mac"
    echo "  ✓ Connect to your Snowflake database"
    echo "  ✓ Access at http://localhost:3000"
    echo ""
    echo "See: deployment/GHCR_LOCAL_DEPLOYMENT.md for details"
    echo ""
    exit 1
fi

# If we got here, SPCS commands work
echo -e "${GREEN}✓ Snowpark Container Services is available${NC}"
echo ""

# Step 2: Create or verify image repository
echo -e "${CYAN}[2/6] Setting up image repository...${NC}"

snow sql --connection "$CONNECTION_NAME" -q "
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE};
USE WAREHOUSE ${WAREHOUSE};

-- Create image repository if it doesn't exist
CREATE IMAGE REPOSITORY IF NOT EXISTS ${IMAGE_REPO};

-- Show repository
SHOW IMAGE REPOSITORIES LIKE '${IMAGE_REPO}';
" || {
    echo -e "${RED}✗ Failed to create image repository${NC}"
    echo ""
    echo -e "${YELLOW}This could mean:${NC}"
    echo "  1. Snowpark Container Services is not enabled"
    echo "  2. Your role doesn't have CREATE IMAGE REPOSITORY privilege"
    echo "  3. The database doesn't exist"
    echo ""
    echo "Try running as ACCOUNTADMIN:"
    echo "  snow sql --connection $CONNECTION_NAME -q \"USE ROLE ACCOUNTADMIN; CREATE IMAGE REPOSITORY ${DATABASE}.PUBLIC.${IMAGE_REPO};\""
    exit 1
}

echo -e "${GREEN}✓ Image repository ready${NC}"
echo ""

# Step 3: Verify images exist on GHCR
echo -e "${CYAN}[3/6] Verifying images exist on GitHub Container Registry...${NC}"
echo ""

if command -v docker &> /dev/null; then
    echo "Checking if images are accessible..."
    
    # Check frontend image
    if docker manifest inspect "$FRONTEND_IMAGE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend image exists: ${FRONTEND_IMAGE}${NC}"
    else
        echo -e "${RED}✗ Frontend image not found: ${FRONTEND_IMAGE}${NC}"
        echo ""
        echo "The image doesn't exist or is not accessible."
        echo ""
        echo "Please verify:"
        echo "  1. Images have been built and pushed:"
        echo "     ./build_and_push_ghcr.sh ${GITHUB_USERNAME} ${VERSION}"
        echo ""
        echo "  2. Images exist at:"
        echo "     https://github.com/${GITHUB_USERNAME}?tab=packages"
        echo ""
        echo "  3. If images are private, make them public:"
        echo "     Go to package settings → Change visibility → Public"
        exit 1
    fi
    
    # Check backend image
    if docker manifest inspect "$BACKEND_IMAGE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Backend image exists: ${BACKEND_IMAGE}${NC}"
    else
        echo -e "${RED}✗ Backend image not found: ${BACKEND_IMAGE}${NC}"
        echo ""
        echo "Please build and push the images first:"
        echo "  ./build_and_push_ghcr.sh ${GITHUB_USERNAME} ${VERSION}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Docker not available, skipping image verification${NC}"
    echo "Assuming images exist at:"
    echo "  - ${FRONTEND_IMAGE}"
    echo "  - ${BACKEND_IMAGE}"
fi

echo ""

# Step 4: Get repository URL and login to registry
echo -e "${CYAN}[4/6] Setting up Docker registry access...${NC}"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo ""
    echo "Please start Docker Desktop and try again."
    echo ""
    echo "To start Docker Desktop:"
    echo "  1. Open Docker Desktop application"
    echo "  2. Wait for it to fully start (whale icon in menu bar)"
    echo "  3. Run this script again"
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"
echo ""

# Get the Snowflake registry URL
echo "Getting Snowflake registry URL..."
REGISTRY_URL=$(snow spcs image-repository url "${IMAGE_REPO}" \
    --database "${DATABASE}" \
    --schema "${SCHEMA}" \
    --connection "$CONNECTION_NAME" 2>&1 | grep -v "^$" | tail -1)

if [[ -z "$REGISTRY_URL" ]]; then
    echo -e "${RED}✗ Failed to get repository URL${NC}"
    exit 1
fi

echo "Repository URL: ${REGISTRY_URL}"
echo ""

# Get registry token and login manually
echo "Logging into Snowflake image registry..."
echo "Getting authentication token..."

# Get the registry token
REGISTRY_TOKEN=$(snow spcs image-registry token \
    --connection "$CONNECTION_NAME" 2>&1 | grep -v "^$" | tail -1)

if [[ -z "$REGISTRY_TOKEN" ]]; then
    echo -e "${RED}✗ Failed to get registry token${NC}"
    exit 1
fi

# Extract just the registry hostname
REGISTRY_HOST=$(echo "$REGISTRY_URL" | cut -d'/' -f1)

# Login using docker login with the token
echo "$REGISTRY_TOKEN" | docker login "$REGISTRY_HOST" -u 0sessiontoken --password-stdin >/dev/null 2>&1 || {
    echo -e "${RED}✗ Failed to login to Snowflake registry${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Make sure Docker Desktop is running"
    echo "  2. Try restarting Docker Desktop"
    echo "  3. Check Docker has network access"
    echo ""
    echo "Manual login command:"
    echo "  snow spcs image-registry token --connection $CONNECTION_NAME | docker login $REGISTRY_HOST -u 0sessiontoken --password-stdin"
    exit 1
}

echo -e "${GREEN}✓ Logged into Snowflake registry${NC}"
echo ""

# Step 5: Pull, tag, and push images
echo -e "${CYAN}[5/6] Pulling and pushing images...${NC}"
echo ""
echo -e "${YELLOW}NOTE: This process can take 5-10 minutes per image.${NC}"
echo ""

# Frontend image
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Processing frontend image..."
echo "  Source: ${FRONTEND_IMAGE}"
echo "  Target: ${REGISTRY_URL}/frontend:${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Pull from GHCR
echo "[1/3] Pulling from GitHub Container Registry..."
docker pull "${FRONTEND_IMAGE}" || {
    echo -e "${RED}✗ Failed to pull frontend image from GHCR${NC}"
    echo ""
    echo "Please verify:"
    echo "  1. Image exists: https://github.com/${GITHUB_USERNAME}?tab=packages"
    echo "  2. Image is public or you're logged in to GHCR"
    echo "  3. Image tag '${VERSION}' exists"
    exit 1
}

# Tag for Snowflake
echo "[2/3] Tagging for Snowflake registry..."
docker tag "${FRONTEND_IMAGE}" "${REGISTRY_URL}/frontend:${VERSION}"

# Push to Snowflake
echo "[3/3] Pushing to Snowflake registry (this may take several minutes)..."
docker push "${REGISTRY_URL}/frontend:${VERSION}" || {
    echo -e "${RED}✗ Failed to push frontend image to Snowflake${NC}"
    exit 1
}

echo -e "${GREEN}✓ Frontend image uploaded successfully${NC}"
echo ""

# Backend image
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Processing backend image..."
echo "  Source: ${BACKEND_IMAGE}"
echo "  Target: ${REGISTRY_URL}/backend:${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Pull from GHCR
echo "[1/3] Pulling from GitHub Container Registry..."
docker pull "${BACKEND_IMAGE}" || {
    echo -e "${RED}✗ Failed to pull backend image from GHCR${NC}"
    exit 1
}

# Tag for Snowflake
echo "[2/3] Tagging for Snowflake registry..."
docker tag "${BACKEND_IMAGE}" "${REGISTRY_URL}/backend:${VERSION}"

# Push to Snowflake
echo "[3/3] Pushing to Snowflake registry (this may take several minutes)..."
docker push "${REGISTRY_URL}/backend:${VERSION}" || {
    echo -e "${RED}✗ Failed to push backend image to Snowflake${NC}"
    exit 1
}

echo -e "${GREEN}✓ Backend image uploaded successfully${NC}"
echo ""
echo -e "${GREEN}✓ All images uploaded to Snowflake${NC}"

echo -e "${GREEN}✓ Backend image pulled${NC}"
echo -e "${GREEN}✓ All images pulled successfully${NC}"
echo ""

# Step 5: List images to verify
echo -e "${CYAN}[5/5] Verifying images in Snowflake repository...${NC}"

snow sql --connection "$CONNECTION_NAME" -q "
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE};

SELECT 
  image_name,
  image_tag,
  created_on,
  size_bytes / 1024 / 1024 AS size_mb
FROM TABLE(SYSTEM\$REGISTRY_LIST_IMAGES('${IMAGE_REPO}'))
WHERE image_name LIKE '%bordereau%'
ORDER BY created_on DESC;
" || echo -e "${YELLOW}⚠ Could not list images${NC}"

echo ""

# Step 6: Create or update service
echo -e "${CYAN}[6/6] Deploying service...${NC}"

# Check if service exists
SERVICE_EXISTS=$(snow sql --connection "$CONNECTION_NAME" --format json -q "
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE};
SHOW SERVICES LIKE '${SERVICE_NAME}';
" | jq -r 'length' 2>/dev/null || echo "0")

if [[ "$SERVICE_EXISTS" -gt 0 ]]; then
    echo "Service ${SERVICE_NAME} exists, updating..."
    
    # Drop existing service
    snow sql --connection "$CONNECTION_NAME" -q "
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE};
DROP SERVICE IF EXISTS ${SERVICE_NAME};
" || echo -e "${YELLOW}⚠ Could not drop existing service${NC}"
    
    # Wait a moment for cleanup
    sleep 5
fi

# Create service with GHCR images
echo "Creating service..."

snow sql --connection "$CONNECTION_NAME" -q "
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE};
USE WAREHOUSE ${WAREHOUSE};

CREATE SERVICE ${SERVICE_NAME}
  IN COMPUTE POOL ${COMPUTE_POOL}
  FROM SPECIFICATION \$\$
    spec:
      containers:
      - name: frontend
        image: /${DATABASE}/${SCHEMA}/${IMAGE_REPO}/frontend:${VERSION}
        env:
          REACT_APP_API_URL: http://localhost:8000
        readinessProbe:
          port: 80
          path: /
      - name: backend
        image: /${DATABASE}/${SCHEMA}/${IMAGE_REPO}/backend:${VERSION}
        env:
          SNOWFLAKE_ACCOUNT: !ref SNOWFLAKE_ACCOUNT
          SNOWFLAKE_USER: !ref SNOWFLAKE_USER
          SNOWFLAKE_PASSWORD: !ref SNOWFLAKE_PASSWORD
          SNOWFLAKE_WAREHOUSE: ${WAREHOUSE}
          SNOWFLAKE_DATABASE: ${DATABASE}
          SNOWFLAKE_ROLE: SYSADMIN
          SNOWFLAKE_BRONZE_SCHEMA: BRONZE
          SNOWFLAKE_SILVER_SCHEMA: SILVER
          SNOWFLAKE_GOLD_SCHEMA: GOLD
        readinessProbe:
          port: 8000
          path: /health
      endpoints:
      - name: frontend
        port: 80
        public: true
  \$\$
  MIN_INSTANCES = 1
  MAX_INSTANCES = 1;
" || {
    echo -e "${RED}✗ Failed to create service${NC}"
    exit 1
}

echo -e "${GREEN}✓ Service created${NC}"
echo ""

# Wait for service to start
echo "Waiting for service to start (this may take a few minutes)..."
sleep 10

# Check service status
echo ""
echo -e "${CYAN}Service Status:${NC}"
snow sql --connection "$CONNECTION_NAME" -q "
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE};

SELECT 
  name,
  status,
  compute_pool,
  created_on
FROM TABLE(INFORMATION_SCHEMA.SERVICES)
WHERE name = '${SERVICE_NAME}';
"

# Get endpoint
echo ""
echo -e "${CYAN}Service Endpoints:${NC}"
snow sql --connection "$CONNECTION_NAME" -q "
USE ROLE SYSADMIN;
USE DATABASE ${DATABASE};

SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME};
" || echo -e "${YELLOW}⚠ Could not retrieve endpoints${NC}"

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Print summary
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              DEPLOYMENT SUMMARY                           ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  Service: ${SERVICE_NAME}"
echo "║  Images: GHCR (${VERSION})"
echo "║  Frontend: ${FRONTEND_IMAGE}"
echo "║  Backend:  ${BACKEND_IMAGE}"
echo "║  Duration: ${MINUTES}m ${SECONDS}s"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Check service status:"
echo "   snow sql --connection $CONNECTION_NAME -q \"SHOW SERVICES LIKE '${SERVICE_NAME}'\""
echo ""
echo "2. Get service endpoint:"
echo "   snow sql --connection $CONNECTION_NAME -q \"SHOW ENDPOINTS IN SERVICE ${SERVICE_NAME}\""
echo ""
echo "3. View service logs:"
echo "   snow sql --connection $CONNECTION_NAME -q \"CALL SYSTEM\\\$GET_SERVICE_LOGS('${SERVICE_NAME}', 0, 'frontend')\""
echo ""
