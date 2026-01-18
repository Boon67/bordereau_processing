#!/bin/bash

# ============================================
# Snowflake Pipeline Backend Server Startup
# ============================================

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     SNOWFLAKE PIPELINE BACKEND SERVER                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Change to backend directory
cd "$(dirname "$0")"

# Function to kill process using a specific port
kill_port() {
    local port=$1
    
    echo -e "${BLUE}ℹ Checking if port $port is in use...${NC}"
    
    # Find PID using the port (macOS compatible)
    local pid=$(lsof -ti :$port 2>/dev/null)
    
    if [ ! -z "$pid" ]; then
        echo -e "${YELLOW}⚠ Port $port is in use by process $pid${NC}"
        echo -e "${YELLOW}  Killing process...${NC}"
        kill -9 $pid 2>/dev/null || true
        sleep 1
        
        # Verify the port is now free
        local check_pid=$(lsof -ti :$port 2>/dev/null)
        if [ -z "$check_pid" ]; then
            echo -e "${GREEN}✓ Port $port is now free${NC}"
        else
            echo -e "${RED}✗ Failed to free port $port${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Port $port is available${NC}"
    fi
    echo ""
}

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}⚠ Virtual environment not found. Creating...${NC}"
    python3 -m venv venv
    echo -e "${GREEN}✓ Virtual environment created${NC}"
fi

# Activate virtual environment
echo -e "${BLUE}ℹ Activating virtual environment...${NC}"
source venv/bin/activate

# Check if dependencies are installed
if ! python -c "import fastapi" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Dependencies not installed. Installing...${NC}"
    pip install -r requirements.txt
    echo -e "${GREEN}✓ Dependencies installed${NC}"
fi

# Check authentication configuration
echo ""
echo -e "${BLUE}ℹ Checking authentication configuration...${NC}"

# Check for session token
if [ -d "$HOME/.snowflake/session/connections" ] && [ "$(ls -A $HOME/.snowflake/session/connections 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Snowflake session token found${NC}"
    AUTH_METHOD="Session Token"
# Check for config file
elif [ ! -z "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓ Configuration file found: $CONFIG_FILE${NC}"
    AUTH_METHOD="Config File"
# Check for snow CLI connection
elif [ ! -z "$SNOW_CONNECTION_NAME" ]; then
    echo -e "${GREEN}✓ Snow CLI connection specified: $SNOW_CONNECTION_NAME${NC}"
    AUTH_METHOD="Snow CLI"
# Check for environment variables
elif [ ! -z "$SNOWFLAKE_ACCOUNT" ] && [ ! -z "$SNOWFLAKE_USER" ]; then
    if [ ! -z "$SNOWFLAKE_TOKEN" ]; then
        echo -e "${GREEN}✓ PAT authentication configured${NC}"
        AUTH_METHOD="PAT (Environment)"
    elif [ ! -z "$SNOWFLAKE_PRIVATE_KEY_PATH" ]; then
        echo -e "${GREEN}✓ Keypair authentication configured${NC}"
        AUTH_METHOD="Keypair (Environment)"
    elif [ ! -z "$SNOWFLAKE_PASSWORD" ]; then
        echo -e "${YELLOW}⚠ Password authentication configured (not recommended for production)${NC}"
        AUTH_METHOD="Password (Environment)"
    else
        echo -e "${RED}✗ No authentication method configured${NC}"
        echo ""
        echo "Please configure authentication using one of the following methods:"
        echo "1. Login with snow CLI: snow connection test"
        echo "2. Set CONFIG_FILE environment variable: export CONFIG_FILE=config.toml"
        echo "3. Set environment variables (see backend/README.md)"
        exit 1
    fi
else
    echo -e "${RED}✗ No authentication method configured${NC}"
    echo ""
    echo "Please configure authentication using one of the following methods:"
    echo "1. Login with snow CLI: snow connection test"
    echo "2. Set CONFIG_FILE environment variable: export CONFIG_FILE=config.toml"
    echo "3. Set environment variables (see backend/README.md)"
    exit 1
fi

# Set default values
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
RELOAD="${RELOAD:-true}"

# Display configuration
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Authentication: $AUTH_METHOD"
echo "  Database: ${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
echo "  Host: $HOST"
echo "  Port: $PORT"
echo ""

# Check and free port if in use
kill_port "$PORT"

# Start the server
echo -e "${GREEN}🚀 Starting backend server...${NC}"
echo ""

# Start uvicorn
if [ "$RELOAD" = "true" ]; then
    python -m uvicorn app.main:app --host "$HOST" --port "$PORT" --reload
else
    python -m uvicorn app.main:app --host "$HOST" --port "$PORT"
fi
