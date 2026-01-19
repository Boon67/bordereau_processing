# Full Stack Deployment to Snowpark Container Services

## Overview

Your Bordereau Processing Pipeline can now be fully deployed to Snowpark Container Services, including both the React frontend and FastAPI backend.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User's Browser                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓ HTTPS
┌─────────────────────────────────────────────────────────────────┐
│              Frontend Service (Snowpark Container)               │
│                                                                  │
│  ┌──────────────────────┐      ┌──────────────────────┐        │
│  │   React Application  │      │   Nginx Web Server   │        │
│  │   (Static Files)     │←─────│   Proxy: /api/* →    │        │
│  │   - Ant Design UI    │      │   Backend Service    │        │
│  │   - TypeScript       │      │                      │        │
│  └──────────────────────┘      └──────────────────────┘        │
│                                                                  │
│  Public Endpoint: https://frontend-xxx.snowflakecomputing.app   │
└─────────────────────────────────────────────────────────────────┘
                              ↓ Internal HTTPS
┌─────────────────────────────────────────────────────────────────┐
│              Backend Service (Snowpark Container)                │
│                                                                  │
│  ┌──────────────────────┐      ┌──────────────────────┐        │
│  │   FastAPI REST API   │─────→│   Snowflake          │        │
│  │   - Python 3.10+     │      │   - SPCS OAuth       │        │
│  │   - Pydantic         │      │   - Auto-refresh     │        │
│  └──────────────────────┘      └──────────────────────┘        │
│                                                                  │
│  Public Endpoint: https://backend-yyy.snowflakecomputing.app    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Snowflake Database                            │
│                                                                  │
│  • Bronze Layer: Raw data ingestion and processing              │
│  • Silver Layer: Transformed and validated data                 │
│  • Tasks: Automated workflows                                   │
│  • Stages: File storage (@SRC, @COMPLETED, @ERROR, @ARCHIVE)   │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

1. **Snowflake CLI** installed and configured
   ```bash
   pip install snowflake-cli-labs
   snow connection test --connection DEPLOYMENT
   ```

2. **Docker** installed
   ```bash
   docker --version
   ```

3. **jq** installed (for JSON parsing)
   ```bash
   # macOS
   brew install jq
   
   # Linux
   sudo apt-get install jq
   ```

### Complete Deployment (3 Steps)

```bash
cd deployment

# Step 1: Deploy Backend API
./deploy_snowpark_container.sh

# Step 2: Deploy Frontend UI
./deploy_frontend_spcs.sh

# Step 3: Get Frontend URL
./manage_frontend_service.sh endpoint
```

That's it! Your complete application is now running in Snowpark Container Services.

## Detailed Deployment Steps

### Step 1: Deploy Backend

```bash
cd deployment
./deploy_snowpark_container.sh
```

**What happens:**
1. ✅ Creates compute pool (if needed)
2. ✅ Creates image repository (if needed)
3. ✅ Builds backend Docker image (FastAPI + Python)
4. ✅ Pushes image to Snowflake registry
5. ✅ Deploys or updates backend service
6. ✅ Configures SPCS OAuth authentication
7. ✅ Provides backend endpoint URL

**Output:**
```
Backend endpoint: https://nrcmn2pb-sfsenorthamerica-tboon-aws2.snowflakecomputing.app
```

### Step 2: Deploy Frontend

```bash
cd deployment
./deploy_frontend_spcs.sh
```

**What happens:**
1. ✅ Validates backend service is running
2. ✅ Gets backend endpoint URL automatically
3. ✅ Creates nginx configuration with backend proxy
4. ✅ Builds frontend Docker image (React + Nginx)
5. ✅ Pushes image to Snowflake registry
6. ✅ Deploys or updates frontend service
7. ✅ Provides frontend endpoint URL

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🎉 FRONTEND DEPLOYMENT SUCCESSFUL!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Frontend URL:    https://abc123...snowflakecomputing.app
  Backend URL:     https://xyz789...snowflakecomputing.app

  Open in browser: https://abc123...snowflakecomputing.app

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 3: Access Application

Open the frontend URL in your browser. You'll have access to:

- **Bronze Layer UI**
  - File upload (drag & drop)
  - Stage management (SRC, COMPLETED, ERROR, ARCHIVE)
  - Processing queue status
  - Raw data viewer
  - Task management

- **Silver Layer UI**
  - Target schema definition
  - Field mapping (manual, ML, LLM)
  - Data transformation wizard
  - Transformed data viewer

## Service Management

### Backend Service

```bash
cd deployment

# Check status and endpoint
./manage_snowpark_service.sh status

# View logs
./manage_snowpark_service.sh logs 100

# Restart service
./manage_snowpark_service.sh restart

# Restart with new image
./manage_snowpark_service.sh restart-image
```

### Frontend Service

```bash
cd deployment

# Check status and endpoint
./manage_frontend_service.sh status

# View logs
./manage_frontend_service.sh logs 100

# Restart service
./manage_frontend_service.sh restart

# Restart with new image
./manage_frontend_service.sh restart-image
```

## Updating Your Application

### Update Backend Code

1. Make changes to `backend/app/`

2. Deploy update:
   ```bash
   cd deployment
   ./deploy_snowpark_container.sh
   ```

3. Script automatically:
   - Detects existing service ✅
   - Builds new image
   - Updates service in-place
   - **Preserves endpoint URL** ✅

### Update Frontend Code

1. Make changes to `frontend/src/`

2. Deploy update:
   ```bash
   cd deployment
   ./deploy_frontend_spcs.sh
   ```

3. Script automatically:
   - Gets current backend endpoint
   - Builds new image
   - Updates service in-place
   - **Preserves endpoint URL** ✅

## Key Features

### 🎯 Complete Stack in Snowflake

- **Frontend**: React + TypeScript + Ant Design
- **Backend**: FastAPI + Python
- **Database**: Snowflake (Bronze + Silver layers)
- **All managed**: No external infrastructure needed

### 🔐 Secure by Default

- **HTTPS**: All endpoints use HTTPS
- **SPCS OAuth**: Backend uses Snowflake-provided credentials
- **No credentials**: No passwords or keys in containers
- **Auto-refresh**: Tokens automatically refreshed by Snowflake

### 📁 Smart Deployment

- **Endpoint preservation**: URLs never change on redeploy
- **Auto-detection**: Detects existing services and updates them
- **Zero downtime**: Services updated with suspend/resume
- **Auto-configuration**: Frontend automatically finds backend

### ⚡ Auto-Scaling

- **Frontend**: 1-3 instances based on load
- **Backend**: 1-3 instances based on load
- **Compute pool**: Shared across services
- **Cost-effective**: Pay only for what you use

### 🔧 Easy Management

- **Separate scripts**: Backend and frontend managed independently
- **Status commands**: Check service health and endpoints
- **Log viewing**: Debug issues with service logs
- **Restart options**: Quick restart or full image update

## Cost Management

### Suspend Services When Not in Use

```bash
cd deployment

# Suspend frontend
./manage_frontend_service.sh suspend

# Suspend backend
./manage_snowpark_service.sh suspend

# Or suspend entire compute pool (suspends all services)
./manage_snowpark_service.sh pool-suspend
```

### Resume Services

```bash
cd deployment

# Resume compute pool
./manage_snowpark_service.sh pool-resume

# Resume backend
./manage_snowpark_service.sh resume

# Resume frontend
./manage_frontend_service.sh resume
```

## Troubleshooting

### Frontend Not Loading

1. Check service status:
   ```bash
   ./manage_frontend_service.sh status
   ```

2. View logs:
   ```bash
   ./manage_frontend_service.sh logs 100
   ```

3. Verify backend is running:
   ```bash
   ./manage_snowpark_service.sh status
   ```

### API Calls Failing

1. Check nginx proxy logs:
   ```bash
   ./manage_frontend_service.sh logs 100 | grep -i error
   ```

2. Test backend directly:
   ```bash
   # Get backend endpoint
   ./manage_snowpark_service.sh endpoint
   
   # Test health endpoint
   curl https://backend-endpoint.../api/health
   ```

### Service Won't Start

1. Check compute pool:
   ```bash
   ./manage_snowpark_service.sh pool-status
   ```

2. View service status:
   ```bash
   # Backend
   ./manage_snowpark_service.sh status
   
   # Frontend
   ./manage_frontend_service.sh status
   ```

3. Check service logs for errors:
   ```bash
   ./manage_snowpark_service.sh logs 50
   ./manage_frontend_service.sh logs 50
   ```

## Architecture Benefits

### Single Domain Experience

- Frontend proxies all `/api/*` requests to backend
- No CORS issues
- Clean URLs for users
- Simplified authentication

### Internal Service Communication

- Frontend → Backend uses internal HTTPS
- Secure service-to-service communication
- No public backend exposure needed (but available)

### Scalability

- Each service scales independently
- 1-3 instances per service
- Auto-scaling based on load
- Shared compute pool for efficiency

### High Availability

- Multiple instances per service
- Automatic failover
- Health checks and readiness probes
- Snowflake-managed infrastructure

## Documentation

- **[deployment/README.md](deployment/README.md)** - Deployment directory overview
- **[deployment/FRONTEND_DEPLOYMENT_GUIDE.md](deployment/FRONTEND_DEPLOYMENT_GUIDE.md)** - Frontend deployment details
- **[deployment/SNOWPARK_CONTAINER_DEPLOYMENT.md](deployment/SNOWPARK_CONTAINER_DEPLOYMENT.md)** - Backend deployment details
- **[deployment/SNOWPARK_QUICK_START.md](deployment/SNOWPARK_QUICK_START.md)** - Quick reference guide

## Summary

You now have a complete, production-ready deployment solution for your Bordereau Processing Pipeline:

✅ **Frontend** - React UI deployed to SPCS  
✅ **Backend** - FastAPI deployed to SPCS  
✅ **Database** - Snowflake Bronze + Silver layers  
✅ **Authentication** - SPCS OAuth (secure, automatic)  
✅ **Scaling** - Auto-scaling (1-3 instances)  
✅ **Updates** - Endpoint-preserving deployments  
✅ **Management** - Easy-to-use scripts  
✅ **Cost-effective** - Pay only for compute used  

**All running in Snowflake with public HTTPS endpoints!** 🎉

---

**Built with ❤️ for Snowpark Container Services**
