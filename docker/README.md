# Docker Configuration

**Container configuration for Snowpark Container Services**

---

## Overview

Docker files for deploying the application to Snowflake's Snowpark Container Services (SPCS).

---

## Files

| File | Purpose |
|------|---------|
| `Dockerfile.backend` | FastAPI backend container |
| `Dockerfile.frontend` | React frontend container |
| `nginx.conf` | Nginx configuration for frontend |
| `snowpark-spec.yaml` | SPCS service specification |

---

## Quick Start

### Build Locally

```bash
# Backend
docker build -f docker/Dockerfile.backend -t backend:latest .

# Frontend
docker build -f docker/Dockerfile.frontend -t frontend:latest .
```

### Deploy to SPCS

```bash
cd deployment
./deploy_container.sh
```

This will:
1. Build Docker images
2. Push to Snowflake registry
3. Create/update SPCS service
4. Provision public endpoint

---

## Container Specifications

### Backend Container
- **Base**: `python:3.11-slim`
- **Port**: 8000
- **Framework**: FastAPI + Uvicorn
- **Dependencies**: Snowflake connector, pandas, scikit-learn

### Frontend Container
- **Base**: `node:18-alpine` (build), `nginx:alpine` (runtime)
- **Port**: 80
- **Framework**: React + TypeScript
- **UI**: Ant Design components

---

## SPCS Service Specification

```yaml
spec:
  containers:
  - name: backend
    image: /bordereau_processing_pipeline/public/bordereau_repository/backend:latest
    env:
      SNOWFLAKE_ACCOUNT: <from_snowflake_context>
      SNOWFLAKE_HOST: <from_snowflake_context>
      SNOWFLAKE_DATABASE: BORDEREAU_PROCESSING_PIPELINE
      SNOWFLAKE_WAREHOUSE: COMPUTE_WH
  
  - name: frontend
    image: /bordereau_processing_pipeline/public/bordereau_repository/frontend:latest
  
  endpoints:
  - name: frontend
    port: 80
    public: true
```

---

## Local Development

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

**Access**: http://localhost:3000

---

## Documentation

**Deployment Guide**: [deployment/README.md](../deployment/README.md)  
**Quick Reference**: [docs/QUICK_REFERENCE.md](../docs/QUICK_REFERENCE.md)  
**Backend Setup**: [backend/README.md](../backend/README.md)

---

**Version**: 3.1 | **Status**: ✅ Production Ready
