# Windows Container Deployment Setup

Quick guide for deploying containers on Windows with Git Bash.

## Quick Fix for "Failed to create stage" Error

If you see `[ERROR] Failed to create stage`, use SYSADMIN for container operations:

### Option 1: Use SYSADMIN for Container Operations Only (Recommended)

```bash
# Create or edit custom.config
cat > deployment/custom.config << 'EOF'
# Use SYSADMIN for container/stage operations
CONTAINER_ROLE="SYSADMIN"

# Keep your custom role for data operations (optional)
# SNOWFLAKE_ROLE="BORDEREAU_PROCESSING_PIPELINE_ADMIN"
EOF

# Run deployment
./deployment/deploy_container.sh
```

**Benefits:**
- ✅ SYSADMIN handles container infrastructure (stages, compute pools, services)
- ✅ Your custom role can still manage data operations
- ✅ No need to grant additional privileges

### Option 2: Use SYSADMIN for Everything

```bash
# Create or edit custom.config
cat > deployment/custom.config << 'EOF'
SNOWFLAKE_ROLE="SYSADMIN"
CONTAINER_ROLE="SYSADMIN"
EOF

# Run deployment
./deployment/deploy_container.sh
```

### Option 3: Grant Privileges to Your Custom Role

If you prefer to use your custom role:

```sql
-- Run as ACCOUNTADMIN or SYSADMIN
USE ROLE SYSADMIN;

-- Grant privileges
GRANT CREATE STAGE ON SCHEMA BORDEREAU_PROCESSING_PIPELINE.PUBLIC 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;

GRANT ALL PRIVILEGES ON SCHEMA BORDEREAU_PROCESSING_PIPELINE.PUBLIC 
TO ROLE BORDEREAU_PROCESSING_PIPELINE_ADMIN;
```

Then run deployment normally.

---

## Complete Windows Setup

### 1. Prerequisites

Install required tools:

```bash
# Check if tools are installed
snow --version
docker --version
jq --version

# If missing, install:
# - Snow CLI: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation
# - Docker Desktop: https://www.docker.com/products/docker-desktop
# - jq: winget install jqlang.jq
```

### 2. Configure Snowflake Connection

```bash
# Test your connection
snow connection test

# If no connection, create one
snow connection add

# List connections
snow connection list
```

### 3. Create Configuration File

```bash
# Navigate to project
cd /c/path/to/bordereau

# Create custom config
cat > deployment/custom.config << 'EOF'
# Snowflake Configuration
SNOWFLAKE_CONNECTION="YOUR_CONNECTION_NAME"  # Or leave empty for default
USE_DEFAULT_CONNECTION="true"
AUTO_APPROVE="true"

# Use SYSADMIN for container operations
CONTAINER_ROLE="SYSADMIN"

# Database Configuration
DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"
SCHEMA_NAME="PUBLIC"

# Service Configuration
SERVICE_NAME="BORDEREAU_APP"
COMPUTE_POOL_NAME="BORDEREAU_COMPUTE_POOL"
REPOSITORY_NAME="BORDEREAU_REPOSITORY"

# Image Configuration
IMAGE_TAG="latest"
EOF
```

### 4. Run Deployment

```bash
# Make sure Docker Desktop is running

# Run deployment
./deployment/deploy_container.sh

# Or use the batch file
./deployment/deploy_container.bat
```

---

## Common Windows Issues

### Issue: "command not found: snow"

**Solution:**
```bash
# Add Snow CLI to PATH
export PATH="$PATH:/c/Users/YOUR_USERNAME/.local/bin"

# Or reinstall Snow CLI
pip install snowflake-cli
```

### Issue: "Docker daemon not running"

**Solution:**
1. Start Docker Desktop
2. Wait for it to fully start (whale icon in system tray)
3. Run deployment again

### Issue: "jq: command not found"

**Solution:**
```bash
# Install jq
winget install jqlang.jq

# Or download from: https://jqlang.github.io/jq/download/
```

### Issue: Path issues with /tmp/

**Solution:**
The script automatically handles Windows paths. If you see path errors:

```bash
# Set TEMP variable
export TEMP="/c/Users/$USERNAME/AppData/Local/Temp"
```

### Issue: Line ending errors (^M)

**Solution:**
```bash
# Convert line endings
dos2unix deployment/deploy_container.sh

# Or configure git
git config --global core.autocrlf input
```

---

## Verification

After deployment:

```bash
# Check service status
snow spcs service status BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC

# View service logs
snow spcs service logs BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC \
  --container-name frontend

# Get service endpoint
snow spcs service describe BORDEREAU_APP \
  --database BORDEREAU_PROCESSING_PIPELINE \
  --schema PUBLIC
```

---

## Configuration Options

### Available Settings in custom.config

```bash
# Connection
SNOWFLAKE_CONNECTION=""              # Connection name or empty for default
USE_DEFAULT_CONNECTION="true"        # Use default connection
AUTO_APPROVE="true"                  # Skip confirmation prompts

# Roles
SNOWFLAKE_ROLE="SYSADMIN"           # Main role for deployment
CONTAINER_ROLE="SYSADMIN"           # Role for container operations (stages, pools, services)

# Database
DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"
SCHEMA_NAME="PUBLIC"

# Service
SERVICE_NAME="BORDEREAU_APP"
COMPUTE_POOL_NAME="BORDEREAU_COMPUTE_POOL"
REPOSITORY_NAME="BORDEREAU_REPOSITORY"

# Images
BACKEND_IMAGE_NAME="bordereau_backend"
FRONTEND_IMAGE_NAME="bordereau_frontend"
IMAGE_TAG="latest"                   # Use specific version for production
```

---

## Troubleshooting

For detailed troubleshooting, see:
- [TROUBLESHOOTING_CONTAINER_DEPLOYMENT.md](TROUBLESHOOTING_CONTAINER_DEPLOYMENT.md)

For general deployment issues, see:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## Support

If issues persist:

1. Check logs in `deployment/logs/`
2. Review Snowflake query history
3. Verify Docker Desktop is running
4. Ensure all prerequisites are installed
5. Try using SYSADMIN role: `CONTAINER_ROLE="SYSADMIN"`
