# Deployment Guide

Complete deployment documentation for the Bordereau Processing Pipeline.

> **📖 For complete documentation, see [docs/README.md](../docs/README.md)**

## Directory Structure

```
deployment/
├── README.md                              # This file
│
├── Core Deployment Scripts
├── deploy.sh                              # Main deployment (Bronze + Silver layers)
├── deploy_bronze.sh                       # Bronze layer only
├── deploy_silver.sh                       # Silver layer only
├── deploy_container.sh                    # Container Services (Recommended)
│
├── Management & Utilities
├── manage_services.sh                     # Service management (Recommended)
├── test_deploy_container.sh               # Test container deployment
├── check_snow_connection.sh               # Connection verification
├── undeploy.sh                            # Remove all resources
│
├── Configuration Files
├── default.config                         # Default configuration
├── custom.config.example                  # Custom config template
├── configure_keypair_auth.sql             # SQL for keypair setup
│
├── Documentation
├── DEPLOYMENT_SNOW_CLI.md                 # Snow CLI deployment guide
├── DEPLOYMENT_SUMMARY.md                  # Deployment summary
├── DEPLOYMENT_SUCCESS.md                  # Latest deployment results
├── TEST_RESULTS.md                        # Container deployment tests
├── SNOWPARK_CONTAINER_DEPLOYMENT.md       # Container deployment guide
├── SNOWPARK_QUICK_START.md                # Quick start guide
├── AUTHENTICATION_SETUP.md                # Authentication setup guide
│
└── legacy/                                # Legacy separate services (not recommended)
    ├── README.md                          # Legacy deployment guide
    ├── deploy_full_stack.sh               # Separate services deployment
    ├── deploy_snowpark_container.sh       # Backend only (legacy)
    ├── deploy_frontend_spcs.sh            # Frontend only (legacy)
    ├── manage_snowpark_service.sh         # Backend management (legacy)
    ├── manage_frontend_service.sh         # Frontend management (legacy)
    └── FULL_STACK_SPCS_DEPLOYMENT.md      # Old architecture docs
```

## Quick Start

### 1. Deploy to Snowflake (Bronze + Silver Layers)

```bash
cd deployment
./deploy.sh
```

### 2. Deploy Container Services to SPCS (Recommended)

Deploy both backend and frontend services:

```bash
cd deployment
./deploy_container.sh
```

**This is the recommended approach** - unified deployment, backend internal-only, more secure.

This single command will:
1. ✅ Deploy backend service (FastAPI)
2. ✅ Verify backend health
3. ✅ Deploy frontend service (React + Nginx)
4. ✅ Verify frontend accessibility
5. ✅ Test frontend-backend communication
6. ✅ Provide both endpoints

**Complete Stack in SPCS:**
- ✅ Frontend (React + Nginx)
- ✅ Backend (FastAPI)
- ✅ Both with public HTTPS endpoints
- ✅ Internal API proxying (no CORS)
- ✅ Automated health checks
- ✅ Communication verification

### Alternative: Deploy Services Separately

### 3. Manage the Unified Service

```bash
cd deployment

# View status
./manage_services.sh status

# View logs
./manage_services.sh logs backend 100
./manage_services.sh logs frontend 50

# Run health checks
./manage_services.sh health

# Restart service
./manage_services.sh restart all
```

## Legacy: Separate Services

For backward compatibility, legacy scripts for separate service deployment are in `legacy/`:

```bash
cd deployment/legacy

# Deploy as separate services (not recommended)
./deploy_full_stack.sh
./deploy_snowpark_container.sh  # Backend only
./deploy_frontend_spcs.sh       # Frontend only
```

**See [`legacy/README.md`](legacy/README.md) for details and migration guide.**

### 4. Manage the Services

**Unified Management (Recommended):**

The `manage_services.sh` script provides comprehensive management for all Snowpark services:

```bash
cd deployment

# Status and Information
./manage_services.sh status              # Both services status
./manage_services.sh status backend      # Backend only
./manage_services.sh status frontend     # Frontend only
./manage_services.sh endpoints           # Show all HTTPS endpoints
./manage_services.sh health              # Run health checks on all services
./manage_services.sh all                 # Complete overview (status + endpoints + health)

# View Logs
./manage_services.sh logs backend 50     # Backend logs (last 50 lines)
./manage_services.sh logs frontend 100   # Frontend logs (last 100 lines)
./manage_services.sh logs all 20         # Both services (20 lines each)

# Service Control
./manage_services.sh restart backend     # Restart backend service
./manage_services.sh restart frontend    # Restart frontend service
./manage_services.sh restart all         # Restart both services
./manage_services.sh suspend backend     # Suspend backend
./manage_services.sh suspend frontend    # Suspend frontend
./manage_services.sh resume backend      # Resume backend
./manage_services.sh resume all          # Resume both services

# Update with New Images
./manage_services.sh restart-image backend   # Update backend with new image
./manage_services.sh restart-image frontend  # Update frontend with new image
./manage_services.sh restart-image all       # Update both services

# Troubleshooting
./manage_services.sh describe backend    # Detailed service info
./manage_services.sh describe frontend   # Detailed service info
```

**Quick Reference:**
- `status` - Check if services are running
- `endpoints` - Get HTTPS URLs
- `health` - Test all endpoints
- `logs` - View recent logs
- `restart` - Restart service
- `restart-image` - Update and restart with new image
- `all` - Show everything at once

**Individual Service Management (Legacy):**

Backend:
```bash
./manage_snowpark_service.sh status      # Show status
./manage_snowpark_service.sh logs 100    # Show logs
./manage_snowpark_service.sh restart     # Restart
```

Frontend:
```bash
./manage_frontend_service.sh status      # Show status
./manage_frontend_service.sh logs 100    # Show logs
./manage_frontend_service.sh restart     # Restart
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

## Full Stack Deployment Details

### Architecture

When you deploy the full stack to Snowpark Container Services, you get:

```
User's Browser
     ↓ HTTPS
┌─────────────────────────────────────────┐
│  Frontend Service (SPCS)                │
│  - React App (Static Files)             │
│  - Nginx Proxy                          │
│  - Routes /api/* → Backend              │
│  Public: https://frontend-xxx.app       │
└─────────────────────────────────────────┘
     ↓ Internal HTTPS
┌─────────────────────────────────────────┐
│  Backend Service (SPCS)                 │
│  - FastAPI REST API                     │
│  - Snowflake Connector                  │
│  - SPCS OAuth Authentication            │
│  Internal: https://backend-xxx.app      │
└─────────────────────────────────────────┘
     ↓
┌─────────────────────────────────────────┐
│  Snowflake Database                     │
│  - Bronze Layer                         │
│  - Silver Layer                         │
└─────────────────────────────────────────┘
```

**Key Benefits:**
- ✅ Single public endpoint for users (frontend)
- ✅ Internal API communication (no CORS issues)
- ✅ Automatic HTTPS for both services
- ✅ Snowflake-native authentication
- ✅ No external infrastructure needed

### Deployment Process

The `deploy_full_stack.sh` script performs these steps:

1. **Backend Deployment**
   - Builds FastAPI Docker image
   - Pushes to Snowflake image repository
   - Creates/updates backend service
   - Waits for service to be ready

2. **Backend Health Check**
   - Tests `/api/health` endpoint
   - Verifies Snowflake connection
   - Ensures API is responding

3. **Frontend Deployment**
   - Builds React + Nginx Docker image
   - Configures Nginx to proxy to backend
   - Pushes to Snowflake image repository
   - Creates/updates frontend service

4. **Frontend Verification**
   - Tests frontend accessibility
   - Verifies static assets load
   - Checks Nginx configuration

5. **Communication Test**
   - Tests frontend → backend API calls
   - Verifies end-to-end connectivity
   - Confirms full stack is operational

**Typical Deployment Time:** 5-8 minutes

## Deployment Features

### Smart Service Updates

The deployment scripts include smart update logic:

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

✅ **Endpoint Preservation** - Your endpoint URLs never change  
✅ **Zero Configuration** - Automatically detects existing services  
✅ **Fast Updates** - Only rebuilds and updates what changed  
✅ **Safe Rollback** - Previous image versions remain in repository  
✅ **Health Verification** - Automated health checks after deployment  
✅ **Communication Testing** - Verifies frontend-backend connectivity

## Individual Service Deployment

### Backend Only Deployment

Deploy just the FastAPI backend:

```bash
cd deployment
./deploy_snowpark_container.sh
```

**What it does:**
- Creates compute pool (if needed)
- Creates image repository (if needed)
- Builds backend Docker image
- Pushes to Snowflake registry
- Creates/updates backend service
- Returns backend HTTPS endpoint

**Use when:**
- Testing backend changes
- Backend-only updates
- Initial backend setup

### Frontend Only Deployment

Deploy just the React frontend:

```bash
cd deployment
./deploy_frontend_spcs.sh
```

**Prerequisites:**
- Backend must be deployed first
- Backend endpoint must be accessible

**What it does:**
- Builds React application
- Configures Nginx proxy to backend
- Builds frontend Docker image
- Pushes to Snowflake registry
- Creates/updates frontend service
- Returns frontend HTTPS endpoint

**Use when:**
- UI changes only
- Frontend configuration updates
- Testing frontend independently  

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

For more detailed information on specific topics:

| Document | Description |
|----------|-------------|
| [DEPLOYMENT_SNOW_CLI.md](DEPLOYMENT_SNOW_CLI.md) | Detailed Snow CLI setup and usage |
| [SNOWPARK_CONTAINER_DEPLOYMENT.md](SNOWPARK_CONTAINER_DEPLOYMENT.md) | In-depth container deployment guide |
| [SNOWPARK_QUICK_START.md](SNOWPARK_QUICK_START.md) | Quick reference for Snowpark services |
| [AUTHENTICATION_SETUP.md](AUTHENTICATION_SETUP.md) | Authentication methods and configuration |
| [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) | Deployment checklist and verification |

**Note:** The main deployment guide (this file) contains all essential information. The additional documents provide deeper technical details for specific scenarios.

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
