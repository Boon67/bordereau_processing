#!/bin/bash
# ============================================
# UNDEPLOY SCRIPT
# ============================================
# WARNING: This will delete the entire database!
# ============================================

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
CONFIG_FILE="${1:-${SCRIPT_DIR}/custom.config}"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="${SCRIPT_DIR}/default.config"
fi

source "$CONFIG_FILE"

echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                  ⚠️  WARNING  ⚠️                           ║${NC}"
echo -e "${RED}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${RED}║  This will DELETE the following:                         ║${NC}"
echo -e "${RED}║  - Database: ${DATABASE_NAME}${NC}"
echo -e "${RED}║  - All data in Bronze and Silver layers                  ║${NC}"
echo -e "${RED}║  - Roles: ${DATABASE_NAME}_*${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Undeploy cancelled."
    exit 0
fi

echo ""
read -p "Type the database name to confirm: " db_confirmation

if [ "$db_confirmation" != "$DATABASE_NAME" ]; then
    echo -e "${RED}Database name does not match. Undeploy cancelled.${NC}"
    exit 1
fi

echo ""
echo "Undeploying..."

# Drop database
snowsql \
    -a "$SNOWFLAKE_ACCOUNT" \
    -u "$SNOWFLAKE_USER" \
    -r "SYSADMIN" \
    -w "$SNOWFLAKE_WAREHOUSE" \
    --authenticator externalbrowser \
    -q "DROP DATABASE IF EXISTS ${DATABASE_NAME};"

# Drop roles
snowsql \
    -a "$SNOWFLAKE_ACCOUNT" \
    -u "$SNOWFLAKE_USER" \
    -r "SYSADMIN" \
    -w "$SNOWFLAKE_WAREHOUSE" \
    --authenticator externalbrowser \
    -q "DROP ROLE IF EXISTS ${DATABASE_NAME}_ADMIN;"

snowsql \
    -a "$SNOWFLAKE_ACCOUNT" \
    -u "$SNOWFLAKE_USER" \
    -r "SYSADMIN" \
    -w "$SNOWFLAKE_WAREHOUSE" \
    --authenticator externalbrowser \
    -q "DROP ROLE IF EXISTS ${DATABASE_NAME}_READWRITE;"

snowsql \
    -a "$SNOWFLAKE_ACCOUNT" \
    -u "$SNOWFLAKE_USER" \
    -r "SYSADMIN" \
    -w "$SNOWFLAKE_WAREHOUSE" \
    --authenticator externalbrowser \
    -q "DROP ROLE IF EXISTS ${DATABASE_NAME}_READONLY;"

echo ""
echo -e "${YELLOW}✓ Undeploy completed${NC}"
echo "Database and roles have been removed."
