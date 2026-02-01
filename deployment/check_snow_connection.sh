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

# Try to list connections (don't fail if this errors)
CONNECTION_OUTPUT=$(snow connection list 2>&1 || true)

# Parse connections from table output
connections=()
while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue
    
    # Skip separator lines (all dashes and pipes)
    [[ "$line" =~ ^[[:space:]]*[-+|]+[[:space:]]*$ ]] && continue
    
    # Skip header line
    [[ "$line" =~ connection_name ]] && continue
    
    # If line contains |, extract first field
    if [[ "$line" == *"|"* ]]; then
        # Get everything before first |
        first_col="${line%%|*}"
        # Trim whitespace
        conn=$(echo "$first_col" | tr -d '[:space:]')
        
        # Check if it's a valid connection name (not empty, not just whitespace)
        if [[ -n "$conn" ]] && [[ ! "$conn" =~ ^[-+]+$ ]]; then
            # Check if we already have this connection (avoid duplicates from multi-line entries)
            if [[ ! " ${connections[@]} " =~ " ${conn} " ]]; then
                connections+=("$conn")
            fi
        fi
    fi
done <<< "$CONNECTION_OUTPUT"

# Check if we found any connections
if [[ ${#connections[@]} -gt 0 ]]; then
    echo -e "${GREEN}✓ Found ${#connections[@]} Snowflake connection(s)${NC}"
    echo ""
    echo -e "${BLUE}Available Snowflake Connections:${NC}"
    echo ""
    echo "$CONNECTION_OUTPUT"
    echo ""
    echo -e "${GREEN}✓ Connection check passed - deployment will use configured connection${NC}"
    exit 0
fi

# Alternative check: see if connections.toml exists and has content
TOML_FILE="$HOME/.snowflake/connections.toml"
if [[ -f "$TOML_FILE" ]] && [[ -s "$TOML_FILE" ]]; then
    echo -e "${GREEN}✓ Snowflake connections file found${NC}"
    echo ""
    echo -e "${CYAN}Connections configured in: $TOML_FILE${NC}"
    echo ""
    
    # Try to show connections
    if command -v grep &> /dev/null; then
        echo -e "${BLUE}Configured connections:${NC}"
        grep -E "^\[connections\." "$TOML_FILE" 2>/dev/null | sed 's/\[connections\.//g' | sed 's/\]//g' || true
        echo ""
    fi
    
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
