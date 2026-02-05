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

# Try to list connections using JSON format
CONNECTION_JSON=$(snow connection list --format json 2>/dev/null || echo "[]")

# Parse connections from JSON output using jq
connections=()
if command -v jq &> /dev/null; then
    while IFS= read -r conn; do
        [[ -n "$conn" ]] && connections+=("$conn")
    done < <(echo "$CONNECTION_JSON" | jq -r '.[].connection_name' 2>/dev/null || true)
fi

# Check if we found any connections
if [[ ${#connections[@]} -gt 0 ]]; then
    echo -e "${GREEN}✓ Found ${#connections[@]} Snowflake connection(s)${NC}"
    echo ""
    echo -e "${BLUE}Available Snowflake Connections:${NC}"
    echo ""
    
    # Display connections in a nice format
    for conn in "${connections[@]}"; do
        is_default=$(echo "$CONNECTION_JSON" | jq -r ".[] | select(.connection_name == \"$conn\") | .is_default" 2>/dev/null)
        if [[ "$is_default" == "true" ]]; then
            echo -e "  • ${GREEN}$conn${NC} (default)"
        else
            echo "  • $conn"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✓ Connection check passed - deployment will use configured connection${NC}"
    exit 0
fi

# No connections found - need to create one
echo -e "${RED}✗ No Snowflake connections found${NC}"
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

echo ""
echo -e "${GREEN}✓ Connection created successfully${NC}"
echo ""
echo "Connection details saved to: ~/.snowflake/connections.toml"
exit 0
