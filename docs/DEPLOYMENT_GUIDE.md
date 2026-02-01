# Deployment Guide

Complete guide for deploying the Bordereau application to various environments.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Configuration](#configuration)
4. [Database Deployment](#database-deployment)
5. [Container Deployment](#container-deployment)
6. [Local Development](#local-development)
7. [Troubleshooting](#troubleshooting)

## Quick Start

### Fastest Path to Deployment

```bash
# 1. Install prerequisites
pip install snowflake-cli-labs

# 2. Configure Snowflake connection
snow connection add

# 3. Deploy database layers
cd deployment
./deploy_windows.sh YOUR_CONNECTION

# 4. Deploy containers from GitHub
./deploy_container_ghcr.sh YOUR_CONNECTION YOUR_GITHUB_USERNAME
```

## Prerequisites

### Required Tools

- **Python 3.8+** - For Snowflake CLI
- **Snowflake CLI** - For deploying to Snowflake
  ```bash
  pip install snowflake-cli-labs
  ```

### Optional Tools

- **Docker Desktop** - For building images or local deployment
- **jq** - For JSON parsing (recommended)
  ```bash
  # macOS
  brew install jq
  
  # Windows
  winget install jqlang.jq
  ```

### Snowflake Requirements

- **Snowflake Account** - Enterprise Edition or higher for SPCS
- **Snowpark Container Services** - Must be enabled for container deployment
- **Appropriate Roles** - SYSADMIN or custom role with required privileges

## Configuration

### Configuration Files

The deployment uses configuration files for settings:

- **`deployment/default.config`** - Default settings (don't modify)
- **`deployment/custom.config`** - Your custom overrides (create this)

### Creating Custom Configuration

```bash
cd deployment
cp custom.config.example custom.config
# Edit custom.config with your settings
```

### Key Configuration Variables

```bash
# Database
DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"
BRONZE_SCHEMA_NAME="BRONZE"
SILVER_SCHEMA_NAME="SILVER"
GOLD_SCHEMA_NAME="GOLD"

# Snowpark Container Services
SERVICE_NAME="BORDEREAU_APP"
COMPUTE_POOL_NAME="BORDEREAU_COMPUTE_POOL"
REPOSITORY_NAME="BORDEREAU_REPOSITORY"
SCHEMA_NAME="PUBLIC"

# Snowflake Connection
SNOWFLAKE_ROLE="SYSADMIN"
SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
```

See [DEPLOYMENT_CONFIG.md](../deployment/DEPLOYMENT_CONFIG.md) for full details.

## Database Deployment

Deploy the Bronze, Silver, and Gold database layers.

### Using Bash (macOS/Linux/Git Bash)

```bash
cd deployment
./deploy_windows.sh YOUR_CONNECTION
```

### Using Windows Batch

```cmd
cd deployment
deploy_windows.bat YOUR_CONNECTION
```

### What Gets Deployed

1. **Bronze Layer** - Raw data ingestion
   - File formats and stages
   - Ingestion procedures
   - Discovery tasks

2. **Silver Layer** - Data transformation
   - Target schemas
   - Field mappings
   - Transformation rules
   - Data quality checks

3. **Gold Layer** - Analytics
   - Business metrics
   - Aggregations
   - Member journeys

## Container Deployment

Deploy the web application to Snowpark Container Services or locally.

### Option 1: Deploy to Snowflake (SPCS)

**Prerequisites:**
- Snowpark Container Services enabled
- Docker Desktop running
- Images built and pushed to GHCR

**Steps:**

```bash
# 1. Build and push images to GitHub Container Registry
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME

# 2. Deploy to Snowflake
cd deployment
./deploy_container_ghcr.sh YOUR_CONNECTION YOUR_GITHUB_USERNAME
```

**What happens:**
1. Checks SPCS availability
2. Creates image repository
3. Pulls images from GHCR
4. Pushes to Snowflake registry
5. Creates compute pool
6. Deploys service

### Option 2: Deploy Locally (Docker)

**Prerequisites:**
- Docker Desktop running
- `.env` file with Snowflake credentials

**Steps:**

```bash
# 1. Create .env file
cat > .env << 'EOF'
SNOWFLAKE_ACCOUNT=your-account
SNOWFLAKE_USER=your-user
SNOWFLAKE_PASSWORD=your-password
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_DATABASE=BORDEREAU_PROCESSING_PIPELINE
SNOWFLAKE_ROLE=SYSADMIN
SNOWFLAKE_BRONZE_SCHEMA=BRONZE
SNOWFLAKE_SILVER_SCHEMA=SILVER
SNOWFLAKE_GOLD_SCHEMA=GOLD
EOF

# 2. Deploy locally
cd deployment
./deploy_local_ghcr.sh YOUR_GITHUB_USERNAME
```

**Access:**
- Frontend: http://localhost:3000
- Backend: http://localhost:8000
- Health: http://localhost:8000/api/health

## Building and Pushing Images

### Build Images Locally

```bash
# macOS/Linux/Git Bash
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME [version]

# Windows
build_and_push_ghcr.bat YOUR_GITHUB_USERNAME [version]
```

### Authentication

**Create GitHub Personal Access Token:**
1. Go to https://github.com/settings/tokens
2. Generate new token (classic)
3. Select `write:packages` and `read:packages` scopes
4. Copy the token

**Login to GHCR:**
```bash
echo YOUR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

### Make Images Public (Optional)

To deploy without authentication:
1. Go to https://github.com/YOUR_USERNAME?tab=packages
2. Click on each package (frontend and backend)
3. Go to Package settings → Change visibility → Public

## Local Development

### Using Docker Compose

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Using GHCR Images

```bash
# Pull and run pre-built images
cd deployment
./deploy_local_ghcr.sh YOUR_GITHUB_USERNAME latest
```

## Troubleshooting

### Snowflake CLI Not Found

**Error:** `snow: command not found`

**Solution:**
```bash
pip install snowflake-cli-labs
# Restart terminal
```

### SPCS Not Available

**Error:** `Unknown function SYSTEM$REGISTRY_PULL_IMAGE`

**Cause:** Snowpark Container Services not enabled

**Solutions:**
1. Contact Snowflake support to enable SPCS
2. Deploy locally instead: `./deploy_local_ghcr.sh`

### Docker Not Running

**Error:** `Cannot connect to the Docker daemon`

**Solution:**
1. Start Docker Desktop
2. Wait for it to fully start
3. Verify: `docker info`

### Image Not Found

**Error:** `manifest unknown` or `not found`

**Solutions:**
1. Build and push images: `./build_and_push_ghcr.sh`
2. Verify images exist: https://github.com/YOUR_USERNAME?tab=packages
3. Make images public or login to GHCR

### Connection Failed

**Error:** `Connection test failed`

**Solutions:**
1. Verify credentials: `snow connection test --connection YOUR_CONNECTION`
2. Check account identifier format: `account.region`
3. Ensure IP not blocked by network policies

### Service Won't Start

**Check service status:**
```bash
snow sql --connection YOUR_CONNECTION -q "
  SELECT name, status, message 
  FROM TABLE(INFORMATION_SCHEMA.SERVICES)
  WHERE name = 'BORDEREAU_APP'
"
```

**View logs:**
```bash
snow sql --connection YOUR_CONNECTION -q "
  CALL SYSTEM\$GET_SERVICE_LOGS('BORDEREAU_APP', 0, 'backend')
"
```

## Platform-Specific Guides

- **Windows:** [WINDOWS_DEPLOYMENT.md](../WINDOWS_DEPLOYMENT.md)
- **GHCR to Snowflake:** [GHCR_DEPLOYMENT.md](../deployment/GHCR_DEPLOYMENT.md)
- **Local GHCR:** [GHCR_LOCAL_DEPLOYMENT.md](../deployment/GHCR_LOCAL_DEPLOYMENT.md)
- **Configuration:** [DEPLOYMENT_CONFIG.md](../deployment/DEPLOYMENT_CONFIG.md)

## Quick Reference

### Deploy Everything

```bash
# 1. Database layers
cd deployment
./deploy_windows.sh YOUR_CONNECTION

# 2. Build images
cd ..
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME

# 3. Deploy containers
cd deployment
./deploy_container_ghcr.sh YOUR_CONNECTION YOUR_GITHUB_USERNAME
```

### Update Deployment

```bash
# 1. Build new version
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME v1.1.0

# 2. Deploy new version
cd deployment
./deploy_container_ghcr.sh YOUR_CONNECTION YOUR_GITHUB_USERNAME v1.1.0
```

### Check Status

```bash
# Service status
snow sql --connection YOUR_CONNECTION -q "SHOW SERVICES"

# Service endpoint
snow sql --connection YOUR_CONNECTION -q "SHOW ENDPOINTS IN SERVICE BORDEREAU_APP"

# View logs
snow sql --connection YOUR_CONNECTION -q "CALL SYSTEM\$GET_SERVICE_LOGS('BORDEREAU_APP', 0, 'backend')"
```

## Additional Resources

- [Architecture Documentation](./ARCHITECTURE.md)
- [Technical Reference](./TECHNICAL_REFERENCE.md)
- [User Guide](./USER_GUIDE.md)
- [Changelog](./CHANGELOG.md)
