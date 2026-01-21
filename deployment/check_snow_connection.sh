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
    
    # Get all connections
    mapfile -t connections < <(snow connection list --format json 2>/dev/null | jq -r '.[].connection_name' 2>/dev/null)
    
    if [[ ${#connections[@]} -eq 0 ]]; then
        echo -e "${RED}✗ No connections found${NC}"
        exit 1
    fi
    
    # Get default connection
    DEFAULT_CONNECTION=$(snow connection list --format json | jq -r '.[] | select(.is_default == true) | .connection_name' 2>/dev/null || echo "")
    
    echo ""
    echo -e "${BLUE}Available Snowflake Connections:${NC}"
    echo ""
    
    # Show all connections
    snow connection list
    echo ""

    # If non-interactive, default to using the existing connection.
    if [[ ! -t 0 ]]; then
        echo -e "${GREEN}✓ Using default connection (non-interactive)${NC}"
        exit 0
    fi

    # Check if USE_DEFAULT_CONNECTION is set to true
    if [[ "${USE_DEFAULT_CONNECTION}" == "true" ]]; then
        if [[ -n "$DEFAULT_CONNECTION" ]]; then
            echo -e "${GREEN}✓ Using default connection: ${DEFAULT_CONNECTION} (USE_DEFAULT_CONNECTION=true)${NC}"
        else
            echo -e "${GREEN}✓ Using existing connection (USE_DEFAULT_CONNECTION=true)${NC}"
        fi
        exit 0
    fi

    # If only one connection, ask to use it
    if [[ ${#connections[@]} -eq 1 ]]; then
        echo -e "${BLUE}Found 1 connection: ${connections[0]}${NC}"
        echo ""
        read -p "Use this connection? (y/n): " use_connection
        
        if [[ "$use_connection" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}✓ Using connection: ${connections[0]}${NC}"
            exit 0
        fi
    else
        # Multiple connections - let deploy.sh handle the selection
        echo -e "${YELLOW}Multiple connections found (${#connections[@]} total)${NC}"
        echo -e "${CYAN}Connection selection will be prompted during deployment${NC}"
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
