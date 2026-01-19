#!/bin/bash

# ============================================
# Push Docker Image to Snowflake Registry
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-SFSENORTHAMERICA-TBOON_AWS2}"
DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
SCHEMA_NAME="${SCHEMA_NAME:-PUBLIC}"
REPOSITORY_NAME="${REPOSITORY_NAME:-BORDEREAU_REPOSITORY}"
IMAGE_NAME="${IMAGE_NAME:-bordereau_backend}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🐳 Push Docker Image to Snowflake"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Account:     $SNOWFLAKE_ACCOUNT"
echo "  Database:    $DATABASE_NAME"
echo "  Schema:      $SCHEMA_NAME"
echo "  Repository:  $REPOSITORY_NAME"
echo "  Image:       $IMAGE_NAME:$IMAGE_TAG"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Check if image repository exists
log_info "Checking if image repository exists..."

REPO_EXISTS=$(snow sql -q "SHOW IMAGE REPOSITORIES LIKE '${REPOSITORY_NAME}' IN SCHEMA ${DATABASE_NAME}.${SCHEMA_NAME}" \
    --connection DEPLOYMENT \
    --format json 2>/dev/null | jq -r 'length' || echo "0")

if [ "$REPO_EXISTS" = "0" ]; then
    log_info "Creating image repository: $REPOSITORY_NAME"
    snow sql -q "
        USE DATABASE ${DATABASE_NAME};
        USE SCHEMA ${SCHEMA_NAME};
        CREATE IMAGE REPOSITORY IF NOT EXISTS ${REPOSITORY_NAME};
    " --connection DEPLOYMENT
    log_success "Image repository created"
else
    log_success "Image repository exists"
fi

# Step 2: Get repository URL
log_info "Getting repository URL..."

REPOSITORY_URL=$(snow sql -q "
    SELECT REPOSITORY_URL 
    FROM ${DATABASE_NAME}.INFORMATION_SCHEMA.IMAGE_REPOSITORIES 
    WHERE REPOSITORY_NAME = '${REPOSITORY_NAME}'
" --connection DEPLOYMENT --format json 2>/dev/null | jq -r '.[0].REPOSITORY_URL' || echo "")

if [ -z "$REPOSITORY_URL" ]; then
    log_error "Failed to get repository URL"
    log_info "Constructing URL manually..."
    REPOSITORY_URL="${SNOWFLAKE_ACCOUNT}.registry.snowflakecomputing.com/${DATABASE_NAME}/${SCHEMA_NAME}/${REPOSITORY_NAME}"
fi

# Convert to lowercase for Docker compatibility
REPOSITORY_URL=$(echo "$REPOSITORY_URL" | tr '[:upper:]' '[:lower:]')

log_success "Repository URL: $REPOSITORY_URL"

# Step 3: Build Docker image
log_info "Building Docker image..."

FULL_IMAGE_NAME="${REPOSITORY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"

# Use existing Dockerfile
if [ -f "docker/Dockerfile.backend" ]; then
    log_info "Using docker/Dockerfile.backend"
    docker build \
        -f docker/Dockerfile.backend \
        -t "$FULL_IMAGE_NAME" \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        . || {
        log_error "Docker build failed"
        exit 1
    }
else
    log_error "docker/Dockerfile.backend not found"
    exit 1
fi

log_success "Docker image built: $FULL_IMAGE_NAME"

# Step 4: Login to Snowflake registry
log_info "Logging into Snowflake Docker registry..."

# Get the registry host
REGISTRY_HOST="${SNOWFLAKE_ACCOUNT}.registry.snowflakecomputing.com"

# Use Snow CLI to authenticate and login to Docker
snow spcs image-registry login \
    --connection DEPLOYMENT \
    --format json 2>/dev/null || {
    log_error "Failed to login to Snowflake registry"
    log_info "Trying alternative authentication method..."
    
    # Alternative: Test connection first
    snow connection test --connection DEPLOYMENT || {
        log_error "Snow CLI connection failed"
        log_info "Please configure your connection:"
        log_info "  snow connection add"
        exit 1
    }
    
    # Try login again
    snow spcs image-registry login --connection DEPLOYMENT || {
        log_error "Docker registry login failed"
        exit 1
    }
}

log_success "Logged into Snowflake Docker registry"

# Step 5: Push image
log_info "Pushing image to Snowflake registry..."
log_info "This may take several minutes depending on image size..."

# Tag the image with the full repository path
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "$FULL_IMAGE_NAME"

# Push using docker
docker push "$FULL_IMAGE_NAME" 2>&1 | tee /tmp/docker_push.log || {
    log_error "Docker push failed"
    log_info "Trying alternative method..."
    
    # Alternative: Use snow spcs image-repository url to upload
    snow spcs image-repository url \
        "$REPOSITORY_NAME" \
        --connection DEPLOYMENT \
        --database "$DATABASE_NAME" \
        --schema "$SCHEMA_NAME" 2>/dev/null || true
    
    # Try push again
    docker push "$FULL_IMAGE_NAME" || {
        log_error "Failed to push image"
        log_info "Please check Docker credentials and try again"
        exit 1
    }
}

log_success "Image pushed successfully!"

# Step 6: List images in repository
log_info "Verifying image in repository..."

snow sql -q "
    SHOW IMAGES IN IMAGE REPOSITORY ${DATABASE_NAME}.${SCHEMA_NAME}.${REPOSITORY_NAME};
" --connection DEPLOYMENT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ IMAGE PUSHED SUCCESSFULLY!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Repository:  $REPOSITORY_URL"
echo "  Image:       $FULL_IMAGE_NAME"
echo ""
echo "  Next steps:"
echo "  1. Create a service using this image"
echo "  2. Or run: ./deploy_snowpark_container.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup
rm -f /tmp/Dockerfile.snowpark
