# Snowflake Pipeline - React + FastAPI Architecture

**Modern web application with React frontend and FastAPI middleware for Snowflake File Processing Pipeline.**

For the consolidated docs hub, see `docs/README.md`.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     React Frontend (Port 3000)              │
│  - Modern UI with Ant Design                                │
│  - TypeScript + Vite                                        │
│  - Bronze & Silver layer management                         │
└─────────────────────────────────────────────────────────────┘
                            ↓ HTTP/REST API
┌─────────────────────────────────────────────────────────────┐
│                  FastAPI Middleware (Port 8000)             │
│  - REST API endpoints                                       │
│  - File upload handling                                     │
│  - Snowflake connector                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓ Snowflake Connector
┌─────────────────────────────────────────────────────────────┐
│                      Snowflake                              │
│  - Bronze Layer (Raw Data)                                  │
│  - Silver Layer (Transformed Data)                          │
│  - Stored Procedures & Tasks                                │
└─────────────────────────────────────────────────────────────┘
```

## Features

### Frontend (React + TypeScript)
- ✅ **Modern UI** with Ant Design components
- ✅ **TPA Selection** at application level
- ✅ **Bronze Layer Pages**:
  - Upload Files (drag & drop)
  - Processing Status (real-time metrics)
  - File Stages browser
  - Raw Data viewer
  - Task Management
- ✅ **Silver Layer Pages**:
  - Target Schema designer
  - Field Mappings (Manual/ML/LLM)
  - Transform monitor
- ✅ **Responsive Design** for desktop and mobile
- ✅ **TypeScript** for type safety

### Backend (FastAPI + Python)
- ✅ **REST API** with automatic OpenAPI docs
- ✅ **File Upload** handling with validation
- ✅ **Snowflake Integration** via snowflake-connector-python
- ✅ **TPA Management** endpoints
- ✅ **Bronze Layer** endpoints (upload, queue, status, tasks)
- ✅ **Silver Layer** endpoints (schemas, mappings, transform)
- ✅ **Health Checks** and monitoring
- ✅ **CORS** configuration for frontend

## Deployment Options

### Option 1: Local Development

**Prerequisites:**
- Node.js 18+ and npm
- Python 3.11+
- Snowflake account with deployed SQL components

**Setup:**

```bash
# 1. Clone and configure
cp .env.example .env
# Edit .env with your Snowflake credentials

# 2. Start Backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# 3. Start Frontend (in new terminal)
cd frontend
npm install
npm run dev
```

Access:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/api/docs

### Option 2: Docker Compose (Local)

**Prerequisites:**
- Docker and Docker Compose installed

**Setup:**

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your Snowflake credentials

# 2. Build and run
docker-compose up --build

# 3. Access application
# Frontend: http://localhost:3000
# Backend: http://localhost:8000
```

**Manage containers:**
```bash
# Stop containers
docker-compose down

# View logs
docker-compose logs -f

# Rebuild after changes
docker-compose up --build
```

### Option 3: Snowpark Container Services

**Prerequisites:**
- Snowflake account with Snowpark Container Services enabled
- Docker installed locally
- Snowflake CLI configured

**Setup:**

```bash
# 1. Build and tag images
docker build -f docker/Dockerfile.backend -t snowflake-pipeline-backend:latest .
docker build -f docker/Dockerfile.frontend -t snowflake-pipeline-frontend:latest .

# 2. Push to Snowflake image repository
snow spcs image-repository create snowflake_pipeline
snow spcs image push snowflake-pipeline-backend:latest /snowflake_pipeline/backend:latest
snow spcs image push snowflake-pipeline-frontend:latest /snowflake_pipeline/frontend:latest

# 3. Create compute pool
snow spcs compute-pool create pipeline_pool \
  --family STANDARD_1 \
  --instance-count 2

# 4. Deploy service
snow spcs service create snowflake_pipeline_service \
  --compute-pool pipeline_pool \
  --spec-file docker/snowpark-spec.yaml

# 5. Get service endpoint
snow spcs service status snowflake_pipeline_service
```

**Manage service:**
```bash
# View logs
snow spcs service logs snowflake_pipeline_service

# Scale service
snow spcs service alter snowflake_pipeline_service \
  --min-instances 2 --max-instances 5

# Stop service
snow spcs service suspend snowflake_pipeline_service

# Delete service
snow spcs service drop snowflake_pipeline_service
```

## API Documentation

### Endpoints

**TPA Management:**
- `GET /api/tpas` - Get all TPAs
- `POST /api/tpas` - Create new TPA

**Bronze Layer:**
- `POST /api/bronze/upload` - Upload file to @SRC stage
- `GET /api/bronze/queue` - Get processing queue
- `GET /api/bronze/status` - Get processing status summary
- `GET /api/bronze/raw-data` - Get raw data records
- `GET /api/bronze/stages/{stage}` - List files in stage
- `POST /api/bronze/discover` - Trigger file discovery
- `POST /api/bronze/process` - Trigger queue processing
- `GET /api/bronze/tasks` - Get tasks status
- `POST /api/bronze/tasks/{task}/resume` - Resume task
- `POST /api/bronze/tasks/{task}/suspend` - Suspend task

**Silver Layer:**
- `GET /api/silver/schemas` - Get target schemas
- `POST /api/silver/schemas` - Create target schema
- `POST /api/silver/tables/create` - Create Silver table
- `GET /api/silver/mappings` - Get field mappings
- `POST /api/silver/mappings` - Create field mapping
- `POST /api/silver/mappings/auto-ml` - Auto-map with ML
- `POST /api/silver/mappings/auto-llm` - Auto-map with LLM
- `POST /api/silver/mappings/{id}/approve` - Approve mapping
- `POST /api/silver/transform` - Transform Bronze to Silver

**Interactive API Docs:**
- Swagger UI: http://localhost:8000/api/docs
- ReDoc: http://localhost:8000/api/redoc

## Project Structure

```
├── frontend/                   # React application
│   ├── src/
│   │   ├── components/        # Reusable components
│   │   ├── pages/             # Page components
│   │   ├── services/          # API service layer
│   │   ├── types/             # TypeScript types
│   │   ├── App.tsx            # Main app component
│   │   └── main.tsx           # Entry point
│   ├── package.json
│   ├── vite.config.ts
│   └── tsconfig.json
│
├── backend/                    # FastAPI application
│   ├── app/
│   │   ├── api/               # API route handlers
│   │   │   ├── bronze.py      # Bronze endpoints
│   │   │   ├── silver.py      # Silver endpoints
│   │   │   └── tpa.py         # TPA endpoints
│   │   ├── services/          # Business logic
│   │   │   └── snowflake_service.py
│   │   ├── config.py          # Configuration
│   │   └── main.py            # FastAPI app
│   └── requirements.txt
│
├── docker/                     # Docker configurations
│   ├── Dockerfile.backend     # Backend container
│   ├── Dockerfile.frontend    # Frontend container
│   ├── nginx.conf             # Nginx config for frontend
│   └── snowpark-spec.yaml     # Snowpark Container Services spec
│
├── docker-compose.yml          # Local Docker Compose
├── .env.example                # Environment template
└── README_REACT.md             # This file
```

## Development

### Frontend Development

```bash
cd frontend

# Install dependencies
npm install

# Run dev server with hot reload
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Lint code
npm run lint
```

### Backend Development

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Run with auto-reload
uvicorn app.main:app --reload --port 8000

# Run tests (if implemented)
pytest

# Format code
black app/
```

### Adding New Features

**Frontend:**
1. Create new page component in `frontend/src/pages/`
2. Add route in `frontend/src/App.tsx`
3. Add API calls in `frontend/src/services/api.ts`
4. Update types in `frontend/src/types/index.ts`

**Backend:**
1. Add endpoint in appropriate router (`backend/app/api/`)
2. Add business logic in `backend/app/services/`
3. Update Pydantic models if needed
4. Test endpoint via `/api/docs`

## Environment Variables

### Backend (.env)
```bash
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ROLE=SYSADMIN
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
DATABASE_NAME=FILE_PROCESSING_PIPELINE
BRONZE_SCHEMA_NAME=BRONZE
SILVER_SCHEMA_NAME=SILVER
```

### Frontend (vite)
```bash
VITE_API_URL=http://localhost:8000
```

## Troubleshooting

### Frontend Issues

**Issue: API calls fail with CORS error**
- Solution: Ensure backend CORS_ORIGINS includes frontend URL
- Check `backend/app/config.py` CORS_ORIGINS setting

**Issue: Build fails**
- Solution: Clear node_modules and reinstall
  ```bash
  rm -rf node_modules package-lock.json
  npm install
  ```

### Backend Issues

**Issue: Snowflake connection fails**
- Solution: Verify credentials in .env file
- Test connection: `python -c "from app.services.snowflake_service import SnowflakeService; SnowflakeService().get_connection()"`

**Issue: Module not found**
- Solution: Ensure you're in backend directory and dependencies are installed
  ```bash
  cd backend
  pip install -r requirements.txt
  ```

### Docker Issues

**Issue: Containers won't start**
- Solution: Check logs
  ```bash
  docker-compose logs backend
  docker-compose logs frontend
  ```

**Issue: Port already in use**
- Solution: Change ports in docker-compose.yml or stop conflicting services

## Performance Optimization

### Frontend
- ✅ Code splitting with React.lazy()
- ✅ Memoization with React.memo()
- ✅ Virtual scrolling for large lists
- ✅ Debounced search inputs
- ✅ Optimized bundle size with Vite

### Backend
- ✅ Connection pooling for Snowflake
- ✅ Async endpoints where possible
- ✅ Response caching for frequent queries
- ✅ Pagination for large datasets
- ✅ Background tasks for long operations

## Security

### Frontend
- ✅ XSS protection with React
- ✅ HTTPS in production
- ✅ Secure cookies
- ✅ Input validation

### Backend
- ✅ CORS configuration
- ✅ Request validation with Pydantic
- ✅ SQL injection prevention
- ✅ File upload validation
- ✅ Rate limiting (can be added)

## Migration from Streamlit

**Key Differences:**
1. **Architecture**: Streamlit (monolithic) → React + FastAPI (separated frontend/backend)
2. **Deployment**: Streamlit in Snowflake → Containerized (Docker/Snowpark)
3. **Scalability**: Single-user → Multi-user with API
4. **Customization**: Limited → Full control over UI/UX
5. **Integration**: Snowflake-only → Can integrate with other services

**Benefits:**
- ✅ Better performance and scalability
- ✅ Modern, responsive UI
- ✅ API-first design for integrations
- ✅ Runs locally or in Snowpark
- ✅ Full TypeScript type safety
- ✅ Production-ready architecture

---

**Version**: 2.0 (React + FastAPI)  
**Last Updated**: January 15, 2026  
**Status**: ✅ Ready for Development and Production
