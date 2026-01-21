#!/bin/bash

# ============================================
# Service Diagnostics Script
# ============================================
# Diagnose issues with Snowpark Container Service creation
# ============================================

set +e  # Don't exit on errors

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 Snowpark Container Service Diagnostics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Configuration
CONNECTION="${1:-DEPLOYMENT}"
DATABASE="${2:-BORDEREAU_PROCESSING_PIPELINE}"
SERVICE_NAME="${3:-BORDEREAU_APP}"
COMPUTE_POOL="${4:-BORDEREAU_COMPUTE_POOL}"
REPOSITORY="${5:-BORDEREAU_REPOSITORY}"

echo -e "${CYAN}Configuration:${NC}"
echo "  Connection:    $CONNECTION"
echo "  Database:      $DATABASE"
echo "  Service:       $SERVICE_NAME"
echo "  Compute Pool:  $COMPUTE_POOL"
echo "  Repository:    $REPOSITORY"
echo ""

# ============================================
# 1. Check Service Status
# ============================================
echo -e "${YELLOW}[1/6]${NC} Checking service status..."
echo ""

SERVICE_STATUS=$(snow sql --connection "$CONNECTION" --format json -q "
USE DATABASE $DATABASE;
SHOW SERVICES LIKE '$SERVICE_NAME';
" 2>/dev/null)

if [ -z "$SERVICE_STATUS" ] || [ "$SERVICE_STATUS" = "[]" ]; then
    echo -e "${GREEN}✓${NC} Service does not exist (ready to create)"
else
    echo -e "${YELLOW}⚠${NC} Service exists:"
    echo "$SERVICE_STATUS" | jq -r '.[] | "  Name: \(.name)\n  State: \(.state)\n  Owner: \(.owner)"'
    echo ""
    echo -e "${BLUE}To drop the service:${NC}"
    echo "  snow sql --connection $CONNECTION -q \"USE DATABASE $DATABASE; DROP SERVICE IF EXISTS $SERVICE_NAME;\""
fi
echo ""

# ============================================
# 2. Check Compute Pool
# ============================================
echo -e "${YELLOW}[2/6]${NC} Checking compute pool..."
echo ""

POOL_STATUS=$(snow sql --connection "$CONNECTION" --format json -q "
SHOW COMPUTE POOLS LIKE '$COMPUTE_POOL';
" 2>/dev/null)

if [ -z "$POOL_STATUS" ] || [ "$POOL_STATUS" = "[]" ]; then
    echo -e "${RED}✗${NC} Compute pool does not exist"
    echo -e "${BLUE}To create:${NC}"
    echo "  snow sql --connection $CONNECTION -q \"CREATE COMPUTE POOL $COMPUTE_POOL MIN_NODES=1 MAX_NODES=3 INSTANCE_FAMILY=CPU_X64_XS;\""
else
    POOL_STATE=$(echo "$POOL_STATUS" | jq -r '.[0].state')
    if [ "$POOL_STATE" = "ACTIVE" ] || [ "$POOL_STATE" = "IDLE" ]; then
        echo -e "${GREEN}✓${NC} Compute pool is ready (state: $POOL_STATE)"
    else
        echo -e "${YELLOW}⚠${NC} Compute pool state: $POOL_STATE"
        echo "  Pool may not be ready. Wait for ACTIVE or IDLE state."
    fi
    echo "$POOL_STATUS" | jq -r '.[] | "  Name: \(.name)\n  State: \(.state)\n  Nodes: \(.num_nodes)\n  Services: \(.num_services)"'
fi
echo ""

# ============================================
# 3. Check Image Repository
# ============================================
echo -e "${YELLOW}[3/6]${NC} Checking image repository..."
echo ""

REPO_STATUS=$(snow sql --connection "$CONNECTION" --format json -q "
USE DATABASE $DATABASE;
SHOW IMAGE REPOSITORIES LIKE '$REPOSITORY';
" 2>/dev/null)

if [ -z "$REPO_STATUS" ] || [ "$REPO_STATUS" = "[]" ]; then
    echo -e "${RED}✗${NC} Image repository does not exist"
    echo -e "${BLUE}To create:${NC}"
    echo "  snow sql --connection $CONNECTION -q \"USE DATABASE $DATABASE; CREATE IMAGE REPOSITORY $REPOSITORY;\""
else
    echo -e "${GREEN}✓${NC} Image repository exists"
fi
echo ""

# ============================================
# 4. Check Images
# ============================================
echo -e "${YELLOW}[4/6]${NC} Checking container images..."
echo ""

IMAGES=$(snow sql --connection "$CONNECTION" --format json -q "
USE DATABASE $DATABASE;
SHOW IMAGES IN IMAGE REPOSITORY $REPOSITORY;
" 2>/dev/null)

if [ -z "$IMAGES" ] || [ "$IMAGES" = "[]" ]; then
    echo -e "${RED}✗${NC} No images found in repository"
    echo -e "${BLUE}To push images:${NC}"
    echo "  cd deployment && ./deploy_container.sh"
else
    IMAGE_COUNT=$(echo "$IMAGES" | jq -r 'length')
    echo -e "${GREEN}✓${NC} Found $IMAGE_COUNT image(s):"
    echo "$IMAGES" | jq -r '.[] | "  - \(.image_name) (created: \(.created_on))"'
fi
echo ""

# ============================================
# 5. Check Service Specification
# ============================================
echo -e "${YELLOW}[5/6]${NC} Checking service specification..."
echo ""

SPEC_FILES=$(snow sql --connection "$CONNECTION" --format json -q "
USE DATABASE $DATABASE;
USE SCHEMA PUBLIC;
LIST @SERVICE_SPECS;
" 2>/dev/null)

if [ -z "$SPEC_FILES" ] || [ "$SPEC_FILES" = "[]" ]; then
    echo -e "${RED}✗${NC} No specification files found"
    echo -e "${BLUE}Stage may not exist or is empty${NC}"
else
    SPEC_COUNT=$(echo "$SPEC_FILES" | jq -r 'length')
    echo -e "${GREEN}✓${NC} Found $SPEC_COUNT specification file(s):"
    echo "$SPEC_FILES" | jq -r '.[] | "  - \(.name) (size: \(.size) bytes)"'
fi
echo ""

# ============================================
# 6. Check Privileges
# ============================================
echo -e "${YELLOW}[6/6]${NC} Checking privileges..."
echo ""

CURRENT_ROLE=$(snow sql --connection "$CONNECTION" --format json -q "
SELECT CURRENT_ROLE() as role;
" 2>/dev/null | jq -r '.[0].ROLE')

echo "  Current role: $CURRENT_ROLE"
echo ""

# Check compute pool grants
POOL_GRANTS=$(snow sql --connection "$CONNECTION" --format json -q "
SHOW GRANTS ON COMPUTE POOL $COMPUTE_POOL;
" 2>/dev/null)

if [ ! -z "$POOL_GRANTS" ] && [ "$POOL_GRANTS" != "[]" ]; then
    echo -e "${GREEN}✓${NC} Compute pool grants exist"
else
    echo -e "${YELLOW}⚠${NC} No grants found on compute pool"
fi
echo ""

# ============================================
# Summary and Recommendations
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Summary and Recommendations${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Determine if ready to create service
READY=true

if [ ! -z "$SERVICE_STATUS" ] && [ "$SERVICE_STATUS" != "[]" ]; then
    echo -e "${YELLOW}⚠${NC} Service already exists - need to drop first"
    READY=false
fi

if [ -z "$POOL_STATUS" ] || [ "$POOL_STATUS" = "[]" ]; then
    echo -e "${RED}✗${NC} Compute pool missing - need to create"
    READY=false
elif [ "$POOL_STATE" != "ACTIVE" ] && [ "$POOL_STATE" != "IDLE" ]; then
    echo -e "${YELLOW}⚠${NC} Compute pool not ready - wait for ACTIVE/IDLE state"
    READY=false
fi

if [ -z "$IMAGES" ] || [ "$IMAGES" = "[]" ]; then
    echo -e "${RED}✗${NC} No images found - need to build and push"
    READY=false
fi

if [ -z "$SPEC_FILES" ] || [ "$SPEC_FILES" = "[]" ]; then
    echo -e "${RED}✗${NC} No specification file - need to upload"
    READY=false
fi

echo ""

if [ "$READY" = true ]; then
    echo -e "${GREEN}✓ All prerequisites met - ready to create service!${NC}"
    echo ""
    echo -e "${CYAN}To create the service:${NC}"
    echo "  cd deployment && ./deploy_container.sh"
else
    echo -e "${YELLOW}⚠ Prerequisites not met - follow recommendations above${NC}"
    echo ""
    echo -e "${CYAN}Quick fix commands:${NC}"
    echo ""
    
    if [ ! -z "$SERVICE_STATUS" ] && [ "$SERVICE_STATUS" != "[]" ]; then
        echo "# Drop existing service"
        echo "snow sql --connection $CONNECTION -q \"USE DATABASE $DATABASE; DROP SERVICE IF EXISTS $SERVICE_NAME;\""
        echo ""
    fi
    
    if [ -z "$POOL_STATUS" ] || [ "$POOL_STATUS" = "[]" ]; then
        echo "# Create compute pool"
        echo "snow sql --connection $CONNECTION -q \"CREATE COMPUTE POOL $COMPUTE_POOL MIN_NODES=1 MAX_NODES=3 INSTANCE_FAMILY=CPU_X64_XS;\""
        echo ""
    fi
    
    if [ -z "$IMAGES" ] || [ "$IMAGES" = "[]" ]; then
        echo "# Build and push images"
        echo "cd deployment && ./deploy_container.sh"
        echo ""
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
