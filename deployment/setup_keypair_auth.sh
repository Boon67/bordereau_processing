#!/bin/bash

# ============================================
# Keypair Authentication Setup for Snowflake
# ============================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     SNOWFLAKE KEYPAIR AUTHENTICATION SETUP                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Create keys directory
KEYS_DIR="$HOME/.snowflake/keys"
mkdir -p "$KEYS_DIR"
chmod 700 "$KEYS_DIR"

PRIVATE_KEY="$KEYS_DIR/demo_svc_key.p8"
PUBLIC_KEY="$KEYS_DIR/demo_svc_key.pub"

echo -e "${BLUE}Step 1: Generating RSA key pair...${NC}"

# Generate private key (unencrypted for simplicity)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out "$PRIVATE_KEY" -nocrypt

# Generate public key
openssl rsa -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY"

# Set permissions
chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"

echo -e "${GREEN}✓ Keys generated:${NC}"
echo "  Private key: $PRIVATE_KEY"
echo "  Public key:  $PUBLIC_KEY"
echo ""

echo -e "${BLUE}Step 2: Extract public key for Snowflake...${NC}"

# Get public key without headers/footers
PUBLIC_KEY_VALUE=$(grep -v "BEGIN PUBLIC" "$PUBLIC_KEY" | grep -v "END PUBLIC" | tr -d '\n')

echo -e "${GREEN}✓ Public key extracted${NC}"
echo ""

# Create SQL file
SQL_FILE="$PWD/configure_keypair_auth.sql"
cat > "$SQL_FILE" << SQLEOF
-- ============================================
-- Configure Keypair Authentication for DEMO_SVC
-- Run this as ACCOUNTADMIN or USERADMIN
-- ============================================

-- Switch to appropriate role
USE ROLE ACCOUNTADMIN;

-- Set the RSA public key for the user
ALTER USER DEMO_SVC SET RSA_PUBLIC_KEY='${PUBLIC_KEY_VALUE}';

-- Verify the configuration
DESC USER DEMO_SVC;

-- Test query (optional)
SELECT 'Keypair authentication configured successfully for DEMO_SVC!' AS STATUS;
SQLEOF

echo -e "${BLUE}Step 3: SQL configuration file created${NC}"
echo -e "${GREEN}✓ File: $SQL_FILE${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  NEXT STEPS${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Run the SQL configuration in Snowflake:"
echo "   ${BLUE}snow sql -f $SQL_FILE --connection DEPLOYMENT${NC}"
echo ""
echo "   OR copy/paste the SQL into Snowflake Web UI"
echo ""
echo "2. Update backend/config.toml with keypair authentication"
echo "   (I'll do this automatically next)"
echo ""
echo "3. Test the connection"
echo ""

echo -e "${GREEN}✓ Keypair setup complete!${NC}"
