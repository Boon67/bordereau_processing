#!/bin/bash
# ============================================
# WINDOWS-SPECIFIC DEPLOYMENT SCRIPT
# ============================================
# Purpose: Deploy to Snowflake on Windows/GitBash without connection testing
# Usage: ./deploy_windows.sh [connection_name]
# ============================================

clear
set -e  # Exit on error


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to print header
print_header() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     SNOWFLAKE FILE PROCESSING PIPELINE DEPLOYMENT         ║"
    echo "║              Windows/GitBash Version                      ║"
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
    echo "  Install with winget: winget install jqlang.jq"
    echo "  Or with Chocolatey: choco install jq"
    echo "  Or download: https://stedolan.github.io/jq/download/"
else
    echo -e "${GREEN}✓ jq is installed${NC}"
fi

# Check if docker is installed (optional, for local testing)
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠ Docker is not installed (optional, only needed for local testing)${NC}"
    echo "  Install: https://www.docker.com/products/docker-desktop"
else
    echo -e "${GREEN}✓ Docker is installed${NC}"
fi

echo ""

if [[ "$MISSING_DEPS" == "true" ]]; then
    echo -e "${RED}✗ Missing required dependencies. Please install them and try again.${NC}"
    exit 1
fi

# Get connection name from argument or prompt user
CONNECTION_NAME="${1:-}"

if [[ -z "$CONNECTION_NAME" ]]; then
    echo ""
    echo -e "${CYAN}Available Snowflake Connections:${NC}"
    echo ""
    
    # Show available connections
    snow connection list 2>&1 || echo -e "${YELLOW}(Could not list connections)${NC}"
    
    echo ""
    echo -e "${YELLOW}Enter the connection name to use for deployment${NC}"
    read -p "Connection name: " CONNECTION_NAME
    
    if [[ -z "$CONNECTION_NAME" ]]; then
        echo -e "${RED}✗ Connection name is required${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Using connection: ${CONNECTION_NAME}${NC}"

# Load configuration
if [[ -f "${SCRIPT_DIR}/default.config" ]]; then
    source "${SCRIPT_DIR}/default.config"
fi

if [[ -f "${SCRIPT_DIR}/custom.config" ]]; then
    source "${SCRIPT_DIR}/custom.config"
fi

# Set defaults
DATABASE="${DATABASE_NAME:-FILE_PROCESSING_PIPELINE}"
WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"
ROLE="${SNOWFLAKE_ROLE:-SYSADMIN}"
BRONZE_SCHEMA="${BRONZE_SCHEMA_NAME:-BRONZE}"
SILVER_SCHEMA="${SILVER_SCHEMA_NAME:-SILVER}"
GOLD_SCHEMA="${GOLD_SCHEMA_NAME:-GOLD}"

# Export for child scripts
export DEPLOY_DATABASE="$DATABASE"
export DEPLOY_WAREHOUSE="$WAREHOUSE"
export DEPLOY_BRONZE_SCHEMA="$BRONZE_SCHEMA"
export DEPLOY_SILVER_SCHEMA="$SILVER_SCHEMA"
export DEPLOY_GOLD_SCHEMA="$GOLD_SCHEMA"
export DEPLOY_ROLE="$ROLE"
export DEPLOY_VERBOSE="false"

# Create logs directory
mkdir -p "${PROJECT_ROOT}/logs"
LOG_FILE="${PROJECT_ROOT}/logs/deployment_$(date +%Y%m%d_%H%M%S).log"

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}DEPLOYMENT CONFIGURATION${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Connection:        ${CYAN}$CONNECTION_NAME${NC}"
echo -e "  Database:          ${CYAN}$DATABASE${NC}"
echo -e "  Warehouse:         ${CYAN}$WAREHOUSE${NC}"
echo -e "  Bronze Schema:     ${CYAN}$BRONZE_SCHEMA${NC}"
echo -e "  Silver Schema:     ${CYAN}$SILVER_SCHEMA${NC}"
echo -e "  Gold Schema:       ${CYAN}$GOLD_SCHEMA${NC}"
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

# Deploy Bronze Layer
echo ""
echo -e "${CYAN}🥉 Deploying Bronze Layer...${NC}"

if bash "${SCRIPT_DIR}/deploy_bronze.sh" "$CONNECTION_NAME"; then
    echo -e "${GREEN}✓ Bronze layer deployed successfully${NC}"
else
    echo -e "${RED}✗ Bronze layer deployment failed${NC}"
    exit 1
fi

# Deploy Silver Layer
echo ""
echo -e "${CYAN}🥈 Deploying Silver Layer...${NC}"

if bash "${SCRIPT_DIR}/deploy_silver.sh" "$CONNECTION_NAME"; then
    echo -e "${GREEN}✓ Silver layer deployed successfully${NC}"
else
    echo -e "${RED}✗ Silver layer deployment failed${NC}"
    exit 1
fi

# Deploy Gold Layer
echo ""
echo -e "${CYAN}🥇 Deploying Gold Layer...${NC}"

export DATABASE_NAME="$DATABASE"
export BRONZE_SCHEMA_NAME="$BRONZE_SCHEMA"
export SILVER_SCHEMA_NAME="$SILVER_SCHEMA"
export GOLD_SCHEMA_NAME="$GOLD_SCHEMA"

if bash "${SCRIPT_DIR}/deploy_gold.sh" "$CONNECTION_NAME"; then
    echo -e "${GREEN}✓ Gold layer deployed successfully${NC}"
else
    echo -e "${RED}✗ Gold layer deployment failed${NC}"
    exit 1
fi

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Print summary
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                  DEPLOYMENT SUMMARY                       ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  Connection: $CONNECTION_NAME"
echo "║  Database: $DATABASE"
echo "║  Bronze Layer: ✓ Deployed"
echo "║  Silver Layer: ✓ Deployed"
echo "║  Gold Layer: ✓ Deployed"
echo "║  Duration: ${MINUTES}m ${SECONDS}s"
echo "║  Log: $LOG_FILE"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Upload sample data:"
echo "   snow stage put sample_data/claims_data/provider_a/*.csv @${DATABASE}.${BRONZE_SCHEMA}.SRC/provider_a/ --connection $CONNECTION_NAME"
echo ""
