#!/bin/bash

# ============================================
# Snowflake Pipeline - Full Stack Startup
# Starts both Backend and Frontend services
# ============================================

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"

# PID file locations
BACKEND_PID_FILE="$SCRIPT_DIR/.backend.pid"
FRONTEND_PID_FILE="$SCRIPT_DIR/.frontend.pid"

# Log files
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
BACKEND_LOG="$LOG_DIR/backend.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"

# Default ports
BACKEND_PORT="${PORT:-8000}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"  # Matches vite.config.ts

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down services...${NC}"
    
    if [ -f "$BACKEND_PID_FILE" ]; then
        BACKEND_PID=$(cat "$BACKEND_PID_FILE")
        if ps -p "$BACKEND_PID" > /dev/null 2>&1; then
            echo -e "${BLUE}Stopping backend (PID: $BACKEND_PID)...${NC}"
            kill "$BACKEND_PID" 2>/dev/null || true
            wait "$BACKEND_PID" 2>/dev/null || true
        fi
        rm -f "$BACKEND_PID_FILE"
    fi
    
    if [ -f "$FRONTEND_PID_FILE" ]; then
        FRONTEND_PID=$(cat "$FRONTEND_PID_FILE")
        if ps -p "$FRONTEND_PID" > /dev/null 2>&1; then
            echo -e "${BLUE}Stopping frontend (PID: $FRONTEND_PID)...${NC}"
            kill "$FRONTEND_PID" 2>/dev/null || true
            wait "$FRONTEND_PID" 2>/dev/null || true
        fi
        rm -f "$FRONTEND_PID_FILE"
    fi
    
    echo -e "${GREEN}✓ Services stopped${NC}"
    exit 0
}

# Function to kill process using a specific port
kill_port() {
    local port=$1
    local port_name=$2
    
    echo -e "${BLUE}ℹ Checking if port $port is in use...${NC}"
    
    # Find PID using the port (macOS compatible)
    local pid=$(lsof -ti :$port 2>/dev/null)
    
    if [ ! -z "$pid" ]; then
        echo -e "${YELLOW}⚠ Port $port is in use by process $pid ($port_name)${NC}"
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

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Print header
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     SNOWFLAKE PIPELINE - FULL STACK STARTUP               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# BACKEND SETUP
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  BACKEND SETUP${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cd "$BACKEND_DIR"

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
    pip install -q -r requirements.txt
    echo -e "${GREEN}✓ Dependencies installed${NC}"
fi

# Check authentication configuration
echo ""
echo -e "${BLUE}ℹ Checking authentication configuration...${NC}"

AUTH_CONFIGURED=false

# Check for session token
if [ -d "$HOME/.snowflake/session/connections" ] && [ "$(ls -A $HOME/.snowflake/session/connections 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Snowflake session token found${NC}"
    AUTH_METHOD="Session Token"
    AUTH_CONFIGURED=true
# Check for config file (explicit CONFIG_FILE env var)
elif [ ! -z "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓ Configuration file found: $CONFIG_FILE${NC}"
    AUTH_METHOD="Config File"
    AUTH_CONFIGURED=true
# Check for config.toml in backend directory
elif [ -f "$BACKEND_DIR/config.toml" ]; then
    export CONFIG_FILE="$BACKEND_DIR/config.toml"
    echo -e "${GREEN}✓ Configuration file found: $CONFIG_FILE${NC}"
    AUTH_METHOD="Config File (backend/config.toml)"
    AUTH_CONFIGURED=true
# Check for snow CLI connection
elif [ ! -z "$SNOW_CONNECTION_NAME" ]; then
    echo -e "${GREEN}✓ Snow CLI connection specified: $SNOW_CONNECTION_NAME${NC}"
    AUTH_METHOD="Snow CLI"
    AUTH_CONFIGURED=true
# Check for environment variables
elif [ ! -z "$SNOWFLAKE_ACCOUNT" ] && [ ! -z "$SNOWFLAKE_USER" ]; then
    if [ ! -z "$SNOWFLAKE_TOKEN" ]; then
        echo -e "${GREEN}✓ PAT authentication configured${NC}"
        AUTH_METHOD="PAT (Environment)"
        AUTH_CONFIGURED=true
    elif [ ! -z "$SNOWFLAKE_PRIVATE_KEY_PATH" ]; then
        echo -e "${GREEN}✓ Keypair authentication configured${NC}"
        AUTH_METHOD="Keypair (Environment)"
        AUTH_CONFIGURED=true
    elif [ ! -z "$SNOWFLAKE_PASSWORD" ]; then
        echo -e "${YELLOW}⚠ Password authentication configured (not recommended for production)${NC}"
        AUTH_METHOD="Password (Environment)"
        AUTH_CONFIGURED=true
    fi
fi

if [ "$AUTH_CONFIGURED" = false ]; then
    echo -e "${RED}✗ No authentication method configured${NC}"
    echo ""
    echo "Please configure authentication using one of the following methods:"
    echo "1. Login with snow CLI: snow connection test"
    echo "2. Set CONFIG_FILE environment variable: export CONFIG_FILE=config.toml"
    echo "3. Set environment variables (see backend/README.md)"
    exit 1
fi

echo ""
echo -e "${BLUE}Backend Configuration:${NC}"
echo "  Authentication: $AUTH_METHOD"
echo "  Database: ${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"
echo "  Host: ${HOST:-0.0.0.0}"
echo "  Port: $BACKEND_PORT"
echo ""

# ============================================
# FRONTEND SETUP
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  FRONTEND SETUP${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cd "$FRONTEND_DIR"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}⚠ Node modules not found. Installing...${NC}"
    npm install
    echo -e "${GREEN}✓ Node modules installed${NC}"
fi

echo ""
echo -e "${BLUE}Frontend Configuration:${NC}"
echo "  Port: $FRONTEND_PORT"
echo "  Backend API: http://localhost:$BACKEND_PORT"
echo ""

# ============================================
# CHECK AND FREE PORTS
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  CHECKING PORTS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check and free backend port
kill_port "$BACKEND_PORT" "Backend"

# Check and free frontend port
kill_port "$FRONTEND_PORT" "Frontend"

# ============================================
# START SERVICES
# ============================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  STARTING SERVICES${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Start Backend
echo -e "${GREEN}🚀 Starting backend server...${NC}"
cd "$BACKEND_DIR"
source venv/bin/activate

# Set environment variables for backend
export HOST="${HOST:-0.0.0.0}"
export PORT="$BACKEND_PORT"
export DATABASE_NAME="${DATABASE_NAME:-BORDEREAU_PROCESSING_PIPELINE}"

# Set Snow CLI connection name (will be used if available)
export SNOW_CONNECTION_NAME="${SNOW_CONNECTION_NAME:-DEPLOYMENT}"

python -m uvicorn app.main:app \
    --host "${HOST:-0.0.0.0}" \
    --port "$BACKEND_PORT" \
    --reload > "$BACKEND_LOG" 2>&1 &

BACKEND_PID=$!
echo $BACKEND_PID > "$BACKEND_PID_FILE"
echo -e "${GREEN}✓ Backend started (PID: $BACKEND_PID)${NC}"
echo -e "${CYAN}  Log: $BACKEND_LOG${NC}"
echo -e "${CYAN}  API: http://localhost:$BACKEND_PORT${NC}"
echo -e "${CYAN}  Docs: http://localhost:$BACKEND_PORT/api/docs${NC}"

# Wait a moment for backend to start
sleep 2

# Start Frontend
echo ""
echo -e "${GREEN}🚀 Starting frontend server...${NC}"
cd "$FRONTEND_DIR"

npm run dev > "$FRONTEND_LOG" 2>&1 &

FRONTEND_PID=$!
echo $FRONTEND_PID > "$FRONTEND_PID_FILE"
echo -e "${GREEN}✓ Frontend started (PID: $FRONTEND_PID)${NC}"
echo -e "${CYAN}  Log: $FRONTEND_LOG${NC}"
echo -e "${CYAN}  URL: http://localhost:$FRONTEND_PORT${NC}"

# ============================================
# RUNNING
# ============================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ ALL SERVICES RUNNING${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}Frontend:${NC}  http://localhost:$FRONTEND_PORT"
echo -e "${CYAN}Backend:${NC}   http://localhost:$BACKEND_PORT"
echo -e "${CYAN}API Docs:${NC}  http://localhost:$BACKEND_PORT/api/docs"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
echo ""

# Monitor processes
while true; do
    # Check if backend is still running
    if ! ps -p "$BACKEND_PID" > /dev/null 2>&1; then
        echo -e "${RED}✗ Backend process died unexpectedly${NC}"
        echo -e "${YELLOW}Check logs: $BACKEND_LOG${NC}"
        cleanup
    fi
    
    # Check if frontend is still running
    if ! ps -p "$FRONTEND_PID" > /dev/null 2>&1; then
        echo -e "${RED}✗ Frontend process died unexpectedly${NC}"
        echo -e "${YELLOW}Check logs: $FRONTEND_LOG${NC}"
        cleanup
    fi
    
    sleep 2
done
