# Deployment Guide

Complete guide for deploying Bordereau to Snowflake.

## Quick Start

```bash
# 1. Install Snowflake CLI
pip install snowflake-cli-labs

# 2. Configure connection
snow connection add

# 3. Deploy database layers
cd deployment
./deploy_windows.sh YOUR_CONNECTION

# 4. Build and push images (if deploying containers)
cd ..
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME

# 5. Deploy containers
cd deployment
./deploy_container_ghcr.sh YOUR_CONNECTION YOUR_GITHUB_USERNAME
```

## Prerequisites

### Required
- **Python 3.8+** and **pip**
- **Snowflake CLI**: `pip install snowflake-cli-labs`
- **Snowflake Account** with SYSADMIN role

### Optional (for containers)
- **Docker Desktop** (for building/running containers)
- **Snowpark Container Services** enabled (for Snowflake deployment)

## Configuration

### Config Files

Create `deployment/custom.config` to override defaults:

```bash
cd deployment
cat > custom.config << 'EOF'
# Custom settings
DATABASE_NAME="MY_PIPELINE"
SERVICE_NAME="MY_APP"
COMPUTE_POOL_NAME="MY_POOL"
REPOSITORY_NAME="MY_IMAGES"
EOF
```

### Key Variables

```bash
DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"  # Database name
BRONZE_SCHEMA_NAME="BRONZE"                    # Bronze schema
SILVER_SCHEMA_NAME="SILVER"                    # Silver schema
GOLD_SCHEMA_NAME="GOLD"                        # Gold schema
SERVICE_NAME="BORDEREAU_APP"                   # Container service name
COMPUTE_POOL_NAME="BORDEREAU_COMPUTE_POOL"     # Compute pool
REPOSITORY_NAME="BORDEREAU_REPOSITORY"         # Image repository
SNOWFLAKE_WAREHOUSE="COMPUTE_WH"               # Warehouse
SNOWFLAKE_ROLE="SYSADMIN"                      # Role
```

## Database Deployment

Deploy Bronze, Silver, and Gold layers:

### macOS/Linux/Git Bash
```bash
cd deployment
./deploy_windows.sh YOUR_CONNECTION
```

### Windows
```cmd
cd deployment
deploy_windows.bat YOUR_CONNECTION
```

### What Gets Deployed

1. **Bronze Layer** - Raw data ingestion, file formats, stages, tasks
2. **Silver Layer** - Transformations, field mappings, data quality
3. **Gold Layer** - Analytics, aggregations, business metrics

## Container Deployment

### Option 1: Snowflake (SPCS)

**Requirements:**
- Snowpark Container Services enabled
- Docker Desktop running
- Images on GitHub Container Registry

**Steps:**

```bash
# 1. Build and push images
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME [version]

# 2. Deploy to Snowflake
cd deployment
./deploy_container_ghcr.sh YOUR_CONNECTION YOUR_GITHUB_USERNAME [version]
```

**What happens:**
- Creates image repository
- Pulls from GHCR, pushes to Snowflake
- Creates compute pool
- Deploys service with frontend + backend

### Option 2: Local (Docker)

**Requirements:**
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

# 2. Deploy
cd deployment
./deploy_local_ghcr.sh YOUR_GITHUB_USERNAME [version]
```

**Access:**
- Frontend: http://localhost:3000
- Backend: http://localhost:8000
- Health: http://localhost:8000/api/health

## Building Images

### Prerequisites

1. **Docker Desktop** running
2. **GitHub Personal Access Token** with `write:packages` and `read:packages`
   - Create at: https://github.com/settings/tokens

### Login to GHCR

```bash
echo YOUR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

### Build and Push

```bash
# macOS/Linux/Git Bash
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME [version]

# Windows
build_and_push_ghcr.bat YOUR_GITHUB_USERNAME [version]

# Examples
./build_and_push_ghcr.sh boon67              # Uses 'latest'
./build_and_push_ghcr.sh boon67 v1.0.0       # Specific version
```

### Make Images Public (Optional)

1. Go to https://github.com/YOUR_USERNAME?tab=packages
2. Click each package (frontend/backend)
3. Package settings → Change visibility → Public

## Available Scripts

### Database Deployment
- `deployment/deploy_windows.sh` - Bash (macOS/Linux/Git Bash)
- `deployment/deploy_windows.bat` - Windows Batch

### Container Deployment
- `deployment/deploy_container_ghcr.sh` - Deploy to Snowflake from GHCR
- `deployment/deploy_local_ghcr.sh` - Deploy locally from GHCR

### Image Management
- `build_and_push_ghcr.sh` - Build and push to GHCR (Bash)
- `build_and_push_ghcr.bat` - Build and push to GHCR (Windows)

## Troubleshooting

### Snowflake CLI Not Found
```bash
pip install snowflake-cli-labs
# Restart terminal
```

### SPCS Not Available
**Error:** `Unknown function SYSTEM$REGISTRY_PULL_IMAGE`

**Solution:** Contact Snowflake to enable SPCS, or deploy locally

### Docker Not Running
```bash
# Start Docker Desktop and verify
docker info
```

### Image Not Found
```bash
# Build and push images
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME

# Verify at https://github.com/YOUR_USERNAME?tab=packages
```

### Connection Failed
```bash
# Test connection
snow connection test --connection YOUR_CONNECTION

# List connections
snow connection list
```

### Service Status
```bash
# Check service
snow sql --connection YOUR_CONNECTION -q "
  SELECT name, status, message 
  FROM TABLE(INFORMATION_SCHEMA.SERVICES)
  WHERE name = 'BORDEREAU_APP'
"

# View logs
snow sql --connection YOUR_CONNECTION -q "
  CALL SYSTEM\$GET_SERVICE_LOGS('BORDEREAU_APP', 0, 'backend')
"
```

## Platform-Specific Notes

### Windows
- Use `.bat` scripts for Command Prompt
- Use `.sh` scripts for Git Bash/WSL
- Docker Desktop required for building images

### macOS/Linux
- Use `.sh` scripts
- Docker required for building images

## Quick Commands

```bash
# Deploy everything
cd deployment && ./deploy_windows.sh YOUR_CONNECTION
cd .. && ./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME
cd deployment && ./deploy_container_ghcr.sh YOUR_CONNECTION YOUR_GITHUB_USERNAME

# Update deployment
./build_and_push_ghcr.sh YOUR_GITHUB_USERNAME v1.1.0
cd deployment && ./deploy_container_ghcr.sh YOUR_CONNECTION YOUR_GITHUB_USERNAME v1.1.0

# Check status
snow sql --connection YOUR_CONNECTION -q "SHOW SERVICES"
snow sql --connection YOUR_CONNECTION -q "SHOW ENDPOINTS IN SERVICE BORDEREAU_APP"

# View logs
snow sql --connection YOUR_CONNECTION -q "CALL SYSTEM\$GET_SERVICE_LOGS('BORDEREAU_APP', 0, 'backend')"
```
