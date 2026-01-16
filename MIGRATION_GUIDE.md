# Migration Guide: Streamlit to React + FastAPI

**Guide for migrating from Streamlit-based architecture to React + FastAPI architecture.**

For the consolidated docs hub, see `docs/README.md`.

## Overview

This guide explains how to transition from the original Streamlit implementation to the new React + FastAPI architecture while maintaining all functionality.

## Architecture Comparison

### Before (Streamlit)
```
┌─────────────────────────────────────┐
│   Streamlit App (in Snowflake)     │
│   - UI and Logic Combined           │
│   - Direct Snowflake Connection     │
│   - Single-user Sessions            │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│         Snowflake                   │
│   - Bronze Layer                    │
│   - Silver Layer                    │
└─────────────────────────────────────┘
```

### After (React + FastAPI)
```
┌─────────────────────────────────────┐
│   React Frontend                    │
│   - Modern UI (Ant Design)          │
│   - TypeScript                      │
│   - Runs in Browser                 │
└─────────────────────────────────────┘
            ↓ REST API
┌─────────────────────────────────────┐
│   FastAPI Middleware                │
│   - REST API Endpoints              │
│   - Business Logic                  │
│   - Snowflake Connector             │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│         Snowflake                   │
│   - Bronze Layer (unchanged)        │
│   - Silver Layer (unchanged)        │
└─────────────────────────────────────┘
```

## Key Benefits

### 1. Separation of Concerns
- **Frontend**: Pure UI/UX with React
- **Backend**: API and business logic with FastAPI
- **Database**: Snowflake (unchanged)

### 2. Deployment Flexibility
- **Local**: Run on your machine for development
- **Docker**: Containerized deployment
- **Snowpark**: Deploy in Snowflake Container Services
- **Cloud**: Deploy to AWS, Azure, GCP

### 3. Scalability
- **Multi-user**: Handle concurrent users
- **Load Balancing**: Scale horizontally
- **Caching**: Add Redis for performance
- **CDN**: Serve static assets globally

### 4. Integration
- **API-First**: Easy integration with other systems
- **Webhooks**: Trigger external processes
- **Authentication**: Add OAuth, SAML, etc.
- **Monitoring**: Integrate with APM tools

## Migration Steps

### Step 1: Keep Snowflake Components (No Changes)

The Bronze and Silver layers remain unchanged:
- ✅ All SQL scripts work as-is
- ✅ Stored procedures unchanged
- ✅ Tasks continue to run
- ✅ Sample data compatible

**No action required** for Snowflake components.

### Step 2: Deploy Backend (FastAPI)

```bash
# 1. Navigate to backend
cd backend

# 2. Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure environment
cp ../.env.example .env
# Edit .env with Snowflake credentials

# 5. Run backend
uvicorn app.main:app --reload --port 8000

# 6. Test API
curl http://localhost:8000/api/health
```

### Step 3: Deploy Frontend (React)

```bash
# 1. Navigate to frontend
cd frontend

# 2. Install dependencies
npm install

# 3. Configure environment
echo "VITE_API_URL=http://localhost:8000" > .env

# 4. Run frontend
npm run dev

# 5. Access application
# Open http://localhost:3000 in browser
```

### Step 4: Test Functionality

**Bronze Layer:**
1. ✅ Upload files via new UI
2. ✅ View processing status
3. ✅ Browse stages
4. ✅ View raw data
5. ✅ Manage tasks

**Silver Layer:**
1. ✅ Define target schemas
2. ✅ Create field mappings
3. ✅ Run transformations
4. ✅ View transformed data

### Step 5: Production Deployment

Choose one of three options:

**Option A: Docker Compose (Recommended for most)**
```bash
docker-compose up --build
```

**Option B: Snowpark Container Services**
```bash
# Build and push images
docker build -f docker/Dockerfile.backend -t backend:latest .
docker build -f docker/Dockerfile.frontend -t frontend:latest .

# Deploy to Snowpark
snow spcs service create snowflake_pipeline_service \
  --compute-pool pipeline_pool \
  --spec-file docker/snowpark-spec.yaml
```

**Option C: Cloud Provider (AWS/Azure/GCP)**
- Deploy backend to ECS/AKS/GKE
- Deploy frontend to S3/Blob/GCS + CloudFront/CDN
- Use managed database for session storage

## Feature Mapping

### Streamlit → React Pages

| Streamlit Page | React Page | Status |
|----------------|------------|--------|
| Upload Files | `/bronze/upload` | ✅ Implemented |
| Processing Status | `/bronze/status` | ✅ Implemented |
| File Stages | `/bronze/stages` | ✅ Implemented |
| Raw Data Viewer | `/bronze/data` | ✅ Implemented |
| Task Management | `/bronze/tasks` | ✅ Implemented |
| Target Schemas | `/silver/schemas` | ✅ Implemented |
| Field Mappings | `/silver/mappings` | ✅ Implemented |
| Transform Monitor | `/silver/transform` | ✅ Implemented |

### API Endpoints

All Streamlit functionality is available via REST API:

```python
# Streamlit (Before)
session.call('discover_files')

# React + FastAPI (After)
POST /api/bronze/discover
```

## Code Examples

### Before: Streamlit File Upload

```python
# Streamlit code
uploaded_file = st.file_uploader("Choose file", type=["csv", "xlsx"])
if uploaded_file:
    session.file.put_stream(uploaded_file, f"@SRC/{tpa}/")
```

### After: React + FastAPI File Upload

```typescript
// React code
const handleUpload = async (file: File) => {
  await apiService.uploadFile(selectedTpa, file);
};

// FastAPI endpoint
@router.post("/upload")
async def upload_file(file: UploadFile, tpa: str):
    sf_service.upload_file_to_stage(file, f"@SRC/{tpa}/")
```

## Troubleshooting

### Issue: Can't connect to Snowflake

**Solution:**
1. Check `.env` file has correct credentials
2. Test connection: `python -c "from app.services.snowflake_service import SnowflakeService; SnowflakeService().get_connection()"`
3. Verify network access to Snowflake

### Issue: Frontend can't reach backend

**Solution:**
1. Ensure backend is running on port 8000
2. Check CORS settings in `backend/app/config.py`
3. Verify `VITE_API_URL` in frontend `.env`

### Issue: Slow performance

**Solution:**
1. Enable connection pooling in Snowflake service
2. Add caching for frequent queries
3. Use pagination for large datasets
4. Consider adding Redis for session storage

## Rollback Plan

If you need to rollback to Streamlit:

1. **Keep Snowflake components** - They're unchanged
2. **Redeploy Streamlit apps** - Original code in `bronze_streamlit/` and `silver_streamlit/`
3. **No data loss** - All data remains in Snowflake

## Next Steps

After migration:

1. **Add Authentication** - Implement OAuth or SAML
2. **Add Monitoring** - Integrate with DataDog, New Relic, etc.
3. **Add Caching** - Use Redis for performance
4. **Add Testing** - Write unit and integration tests
5. **Add CI/CD** - Automate deployments
6. **Add Documentation** - API docs with Swagger

## Support

For migration assistance:
- Review `README_REACT.md` for detailed setup
- Check API docs at `/api/docs`
- Test endpoints via Swagger UI
- Review Docker configurations

---

**Version**: 2.0  
**Last Updated**: January 15, 2026  
**Status**: ✅ Migration Complete
