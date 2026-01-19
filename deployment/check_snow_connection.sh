#!/bin/bash
# ============================================
# CHECK SNOWFLAKE CLI CONNECTION
# ============================================
# Purpose: Check if snow CLI is configured and set up connection if needed
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Checking Snowflake CLI configuration...${NC}"

# Check if snow CLI is installed
if ! command -v snow &> /dev/null; then
    echo -e "${RED}✗ Snowflake CLI (snow) is not installed${NC}"
    echo ""
    echo "Please install Snowflake CLI:"
    echo "  pip install snowflake-cli-labs"
    echo ""
    echo "Or visit: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation"
    exit 1
fi

echo -e "${GREEN}✓ Snowflake CLI is installed${NC}"

# Check if there's an active connection
if snow connection test &> /dev/null; then
    echo -e "${GREEN}✓ Active Snowflake connection found${NC}"
    
    # Get connection details
    CONNECTION_NAME=$(snow connection list --format json | jq -r '.[] | select(.is_default == true) | .connection_name' 2>/dev/null || echo "default")
    
    echo ""
    echo -e "${BLUE}Current connection: ${CONNECTION_NAME}${NC}"

    # Show connection details (without password)
    snow connection list

    # If non-interactive, default to using the existing connection.
    if [[ ! -t 0 ]]; then
        echo ""
        echo -e "${GREEN}✓ Using existing connection (non-interactive)${NC}"
        exit 0
    fi

    echo ""
    read -p "Use this connection? (y/n): " use_connection

    if [[ "$use_connection" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Using existing connection${NC}"
        exit 0
    fi
fi

# No connection or user wants to create new one
echo ""
echo -e "${YELLOW}Setting up new Snowflake connection...${NC}"
echo ""

# Interactive connection setup
echo "Please provide your Snowflake connection details:"
echo ""

read -p "Connection name (default: pipeline): " CONNECTION_NAME
CONNECTION_NAME=${CONNECTION_NAME:-pipeline}

read -p "Account identifier (e.g., abc12345.us-east-1): " ACCOUNT
while [[ -z "$ACCOUNT" ]]; do
    echo -e "${RED}Account is required${NC}"
    read -p "Account identifier: " ACCOUNT
done

read -p "Username: " USER
while [[ -z "$USER" ]]; do
    echo -e "${RED}Username is required${NC}"
    read -p "Username: " USER
done

read -sp "Password: " PASSWORD
echo ""
while [[ -z "$PASSWORD" ]]; do
    echo -e "${RED}Password is required${NC}"
    read -sp "Password: " PASSWORD
    echo ""
done

read -p "Role (default: SYSADMIN): " ROLE
ROLE=${ROLE:-SYSADMIN}

read -p "Warehouse (default: COMPUTE_WH): " WAREHOUSE
WAREHOUSE=${WAREHOUSE:-COMPUTE_WH}

read -p "Database (default: FILE_PROCESSING_PIPELINE): " DATABASE
DATABASE=${DATABASE:-FILE_PROCESSING_PIPELINE}

# Create connection using snow CLI
echo ""
echo -e "${CYAN}Creating connection...${NC}"

snow connection add \
    --connection-name "$CONNECTION_NAME" \
    --account "$ACCOUNT" \
    --user "$USER" \
    --password "$PASSWORD" \
    --role "$ROLE" \
    --warehouse "$WAREHOUSE" \
    --database "$DATABASE" \
    --default

# Test connection
echo ""
echo -e "${CYAN}Testing connection...${NC}"

if snow connection test --connection "$CONNECTION_NAME"; then
    echo ""
    echo -e "${GREEN}✓ Connection established successfully${NC}"
    echo ""
    echo "Connection details saved to: ~/.snowflake/connections.toml"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Connection test failed${NC}"
    echo "Please check your credentials and try again"
    exit 1
fi
