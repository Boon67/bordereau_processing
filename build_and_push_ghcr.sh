#!/bin/bash
# ============================================
# BUILD AND PUSH IMAGES TO GITHUB CONTAINER REGISTRY
# ============================================
# Purpose: Build Docker images and push to ghcr.io
# Usage: ./build_and_push_ghcr.sh [github_username] [version]
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get parameters
GITHUB_USERNAME="${1:-}"
VERSION="${2:-latest}"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     BUILD AND PUSH TO GITHUB CONTAINER REGISTRY           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Get GitHub username if not provided
if [[ -z "$GITHUB_USERNAME" ]]; then
    # Try to detect from git remote
    if git remote get-url origin &> /dev/null; then
        DETECTED_USERNAME=$(git remote get-url origin | sed -E 's/.*[:/]([^/]+)\/[^/]+\.git/\1/')
        if [[ -n "$DETECTED_USERNAME" ]]; then
            echo -e "${CYAN}Detected GitHub username from git: ${DETECTED_USERNAME}${NC}"
            read -p "Use this username? (y/n): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                GITHUB_USERNAME="$DETECTED_USERNAME"
            fi
        fi
    fi
    
    if [[ -z "$GITHUB_USERNAME" ]]; then
        read -p "GitHub username (for ghcr.io/USERNAME/bordereau): " GITHUB_USERNAME
    fi
fi

if [[ -z "$GITHUB_USERNAME" ]]; then
    echo -e "${RED}✗ GitHub username is required${NC}"
    exit 1
fi

echo -e "${CYAN}Configuration:${NC}"
echo -e "  GitHub User:    ${GREEN}${GITHUB_USERNAME}${NC}"
echo -e "  Version:        ${GREEN}${VERSION}${NC}"
echo ""

# Set image names
REPO_PREFIX="ghcr.io/${GITHUB_USERNAME}/bordereau"
FRONTEND_IMAGE="${REPO_PREFIX}/frontend:${VERSION}"
BACKEND_IMAGE="${REPO_PREFIX}/backend:${VERSION}"

echo -e "  Frontend Image: ${GREEN}${FRONTEND_IMAGE}${NC}"
echo -e "  Backend Image:  ${GREEN}${BACKEND_IMAGE}${NC}"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"
echo ""

# Check GHCR authentication
echo -e "${CYAN}Checking GHCR authentication...${NC}"
echo ""
echo "To log in to GitHub Container Registry:"
echo "  1. Create a Personal Access Token at:"
echo "     https://github.com/settings/tokens"
echo "  2. Grant 'write:packages' and 'read:packages' scopes"
echo "  3. Run: echo YOUR_TOKEN | docker login ghcr.io -u ${GITHUB_USERNAME} --password-stdin"
echo ""
read -p "Press Enter once you're logged in, or Ctrl+C to exit..."
echo ""

# Build frontend
echo -e "${CYAN}[1/4] Building frontend image...${NC}"
docker build \
    -f docker/Dockerfile.frontend \
    -t "${FRONTEND_IMAGE}" \
    --build-arg APP_NAME="Bordereau Pipeline" \
    --build-arg API_URL="/api" \
    . || {
    echo -e "${RED}✗ Failed to build frontend image${NC}"
    exit 1
}

echo -e "${GREEN}✓ Frontend image built${NC}"
echo ""

# Build backend
echo -e "${CYAN}[2/4] Building backend image...${NC}"
docker build \
    -f docker/Dockerfile.backend \
    -t "${BACKEND_IMAGE}" \
    --build-arg ALLOWED_LLM_MODELS="CLAUDE-4-SONNET,OPENAI-GPT-4.1" \
    . || {
    echo -e "${RED}✗ Failed to build backend image${NC}"
    exit 1
}

echo -e "${GREEN}✓ Backend image built${NC}"
echo ""

# Push frontend
echo -e "${CYAN}[3/4] Pushing frontend image to GHCR...${NC}"
docker push "${FRONTEND_IMAGE}" || {
    echo -e "${RED}✗ Failed to push frontend image${NC}"
    echo "Make sure you're logged in: docker login ghcr.io"
    exit 1
}

echo -e "${GREEN}✓ Frontend image pushed${NC}"
echo ""

# Push backend
echo -e "${CYAN}[4/4] Pushing backend image to GHCR...${NC}"
docker push "${BACKEND_IMAGE}" || {
    echo -e "${RED}✗ Failed to push backend image${NC}"
    exit 1
}

echo -e "${GREEN}✓ Backend image pushed${NC}"
echo ""

# Also tag as latest if version is not "latest"
if [[ "$VERSION" != "latest" ]]; then
    echo -e "${CYAN}Tagging as latest...${NC}"
    
    docker tag "${FRONTEND_IMAGE}" "${REPO_PREFIX}/frontend:latest"
    docker tag "${BACKEND_IMAGE}" "${REPO_PREFIX}/backend:latest"
    
    docker push "${REPO_PREFIX}/frontend:latest"
    docker push "${REPO_PREFIX}/backend:latest"
    
    echo -e "${GREEN}✓ Also tagged and pushed as 'latest'${NC}"
    echo ""
fi

# Summary
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              BUILD AND PUSH COMPLETE                      ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  Images pushed to GitHub Container Registry:             ║"
echo "║                                                           ║"
echo "║  Frontend: ${FRONTEND_IMAGE}"
echo "║  Backend:  ${BACKEND_IMAGE}"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}🎉 Success!${NC}"
echo ""
echo "Next steps:"
echo "1. Make images public (optional):"
echo "   - Go to https://github.com/${GITHUB_USERNAME}?tab=packages"
echo "   - Click on each package"
echo "   - Go to Package settings → Change visibility → Public"
echo ""
echo "2. Deploy to Snowflake:"
echo "   ./deployment/deploy_container_ghcr.sh [connection_name] ${GITHUB_USERNAME} ${VERSION}"
echo ""
echo "3. View images:"
echo "   https://github.com/${GITHUB_USERNAME}?tab=packages"
echo ""
