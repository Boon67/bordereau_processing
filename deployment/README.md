# Deployment Guide

Complete deployment documentation for the Bordereau Processing Pipeline.

> **📖 For complete documentation, see [docs/README.md](../docs/README.md)**

## Directory Structure

```
deployment/
├── README.md                              # This file
├── deploy.sh                              # Main deployment script (Bronze + Silver)
├── deploy_bronze.sh                       # Bronze layer deployment
├── deploy_silver.sh                       # Silver layer deployment
├── deploy_snowpark_container.sh           # Snowpark Container Services deployment
├── manage_snowpark_service.sh             # Service management utilities
├── setup_keypair_auth.sh                  # Keypair authentication setup
├── check_snow_connection.sh               # Connection verification
├── undeploy.sh                            # Remove all resources
├── default.config                         # Default configuration
├── custom.config.example                  # Custom config template
├── configure_keypair_auth.sql             # SQL for keypair setup
├── DEPLOYMENT_SNOW_CLI.md                 # Snow CLI deployment guide
├── DEPLOYMENT_SUMMARY.md                  # Deployment summary
├── SNOWPARK_CONTAINER_DEPLOYMENT.md       # Container deployment guide
├── SNOWPARK_QUICK_START.md                # Quick start guide
└── AUTHENTICATION_SETUP.md                # Authentication setup guide
```

## Quick Start

### 1. Deploy to Snowflake (Bronze + Silver Layers)

```bash
cd deployment
./deploy.sh
```

### 2. Deploy to Snowpark Container Services

```bash
cd deployment
./deploy_snowpark_container.sh
```

**Important:** When redeploying, the script will automatically:
- Detect if the service already exists
- Update the service with the new image
- Preserve the existing endpoint (no endpoint change!)
- Suspend → Update → Resume the service

### 3. Manage the Service

```bash
cd deployment

# Check status
./manage_snowpark_service.sh status

# View logs
./manage_snowpark_service.sh logs 100

# Get endpoint
./manage_snowpark_service.sh endpoint

# Restart service
./manage_snowpark_service.sh restart

# Suspend/Resume
./manage_snowpark_service.sh suspend
./manage_snowpark_service.sh resume
```

## Configuration

### Default Configuration

Edit `deployment/default.config` to set default values:

```bash
# Snowflake Configuration
SNOWFLAKE_ACCOUNT="SFSENORTHAMERICA-TBOON_AWS2"
SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
DATABASE_NAME="BORDEREAU_PROCESSING_PIPELINE"
BRONZE_SCHEMA_NAME="BRONZE"
SILVER_SCHEMA_NAME="SILVER"
```

### Custom Configuration

Create `deployment/custom.config` to override defaults:

```bash
cp deployment/custom.config.example deployment/custom.config
# Edit custom.config with your values
```

## Deployment Features

### Smart Service Updates

The `deploy_snowpark_container.sh` script now includes smart update logic:

**First Deployment:**
- Creates compute pool
- Creates image repository
- Builds and pushes Docker image
- Creates new service
- Generates new endpoint

**Subsequent Deployments:**
- Reuses existing compute pool and repository
- Builds and pushes new Docker image
- **Updates existing service** (preserves endpoint!)
- Suspends → Updates spec → Resumes service
- No endpoint change, no downtime during update

### Benefits

✅ **Endpoint Preservation** - Your endpoint URL never changes  
✅ **Zero Configuration** - Automatically detects existing services  
✅ **Fast Updates** - Only rebuilds and updates what changed  
✅ **Safe Rollback** - Previous image versions remain in repository  

## Scripts Overview

### Main Deployment Scripts

- **`deploy.sh`** - Master deployment script for Bronze and Silver layers
- **`deploy_bronze.sh`** - Deploys Bronze layer (stages, tables, procedures, tasks)
- **`deploy_silver.sh`** - Deploys Silver layer (schemas, mappings, transformations)
- **`deploy_snowpark_container.sh`** - Deploys backend to Snowpark Container Services

### Management Scripts

- **`manage_snowpark_service.sh`** - Comprehensive service management
  - Status checking
  - Log viewing
  - Endpoint retrieval
  - Start/Stop/Restart operations

### Setup Scripts

- **`setup_keypair_auth.sh`** - Interactive keypair authentication setup
- **`check_snow_connection.sh`** - Verify Snow CLI connection
- **`undeploy.sh`** - Remove all deployed resources

### Configuration Files

- **`default.config`** - Default configuration values
- **`custom.config.example`** - Template for custom configuration
- **`configure_keypair_auth.sql`** - SQL commands for keypair setup

## Additional Documentation

| Document | Description |
|----------|-------------|
| [DEPLOYMENT_SNOW_CLI.md](DEPLOYMENT_SNOW_CLI.md) | Detailed Snow CLI deployment guide |
| [SNOWPARK_CONTAINER_DEPLOYMENT.md](SNOWPARK_CONTAINER_DEPLOYMENT.md) | Container deployment documentation |
| [SNOWPARK_QUICK_START.md](SNOWPARK_QUICK_START.md) | Quick reference for container services |
| [AUTHENTICATION_SETUP.md](AUTHENTICATION_SETUP.md) | Authentication configuration guide |
| [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) | Deployment summary and checklist |

## Path References

All scripts in this directory automatically reference the correct paths:

- **Project Root:** `../` (parent directory)
- **Bronze SQL:** `../bronze/*.sql`
- **Silver SQL:** `../silver/*.sql`
- **Docker Files:** `../docker/Dockerfile.backend`
- **Logs:** `../logs/`

## Examples

### Full Deployment

```bash
# Deploy everything
cd deployment
./deploy.sh

# Deploy container service
./deploy_snowpark_container.sh

# Check service status
./manage_snowpark_service.sh status
```

### Update Container Image

```bash
# Make code changes in backend/app/
# Then redeploy (endpoint will be preserved!)
cd deployment
./deploy_snowpark_container.sh
```

### View Service Logs

```bash
cd deployment
./manage_snowpark_service.sh logs 200
```

### Get Service Endpoint

```bash
cd deployment
./manage_snowpark_service.sh endpoint
```

## Troubleshooting

### Service Won't Start

```bash
# Check service status
./manage_snowpark_service.sh status

# View logs
./manage_snowpark_service.sh logs 100

# Check compute pool
snow sql -q "DESCRIBE COMPUTE POOL BORDEREAU_COMPUTE_POOL" --connection DEPLOYMENT
```

### Endpoint Not Available

The endpoint may take 2-3 minutes to provision after service creation. Check again:

```bash
./manage_snowpark_service.sh endpoint
```

### Authentication Issues

```bash
# Test connection
./check_snow_connection.sh

# Setup keypair auth
./setup_keypair_auth.sh
```

## Important Notes

- ✅ All scripts should be run from the `deployment/` directory
- ✅ Scripts automatically handle path resolution to project files
- ✅ Configuration files are loaded in order: default.config → custom.config → command line args
- ✅ Service updates preserve endpoints (no URL changes on redeploy)

## Related Documentation

- [Documentation Hub](../docs/README.md) - Complete documentation index
- [Quick Start Guide](../QUICK_START.md) - Get running in 10 minutes
- [Backend README](../backend/README.md) - Backend API documentation
- [User Guide](../docs/USER_GUIDE.md) - Usage instructions

---

**Version**: 1.0 | **Last Updated**: January 19, 2026 | **Status**: ✅ Production Ready
