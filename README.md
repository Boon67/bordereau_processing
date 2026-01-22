# Bordereau Processing Pipeline

A modern healthcare claims data processing pipeline built with **FastAPI**, **React**, and **Snowflake**.

## 🌟 Key Features

- **Bronze Layer**: Automated file ingestion with TPA-based multi-tenant isolation
- **Silver Layer**: Intelligent data transformation with ML/LLM-powered field mapping
- **Modern UI**: React + TypeScript with Ant Design components
- **Flexible Deployment**: Local, Docker, or Snowpark Container Services
- **Multi-Auth**: Snow CLI, PAT, or Keypair authentication

## 🏗️ Architecture

```mermaid
graph TD
    A[React Frontend<br/>TypeScript + Ant Design] -->|REST API| B[FastAPI Backend<br/>Python 3.10+]
    B -->|Snowflake Connector| C[Snowflake<br/>Bronze + Silver Layers]
    
    style A fill:#61dafb,stroke:#333,stroke-width:2px,color:#000
    style B fill:#009688,stroke:#333,stroke-width:2px,color:#fff
    style C fill:#29b5e8,stroke:#333,stroke-width:2px,color:#fff
```

## 🚀 Quick Start

### 1. Prerequisites
- Python 3.10+, Node.js 18+
- Snowflake account with admin privileges
- Snow CLI installed (recommended)

### 2. Deploy to Snowflake
```bash
cd deployment
./deploy.sh  # Deploys Bronze + Silver layers
```

### 3. Start the Application
```bash
./start.sh  # Starts backend + frontend
```

### 4. Access the Application
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000/api/docs

### 5. Upload Sample Data
1. Open frontend at http://localhost:3000
2. Select a TPA (e.g., `provider_a`)
3. Upload files from `sample_data/claims_data/`
4. Monitor processing in Bronze Status page

**For detailed setup instructions, see [Quick Start Guide](QUICK_START.md)**

## 📦 Deployment Options

### Local Development
```bash
./start.sh  # Starts both backend and frontend
```

### Snowflake (Bronze + Silver Layers)
```bash
cd deployment
./deploy.sh
```

### Snowpark Container Services (Full Stack)
```bash
cd deployment
./deploy_container.sh  # Deploys backend + frontend with health checks
```

**Features**: 
- ✅ Single command deployment
- ✅ Automated health checks
- ✅ Frontend-backend communication verification
- ✅ Smart updates with zero downtime
- ✅ Endpoint preservation on redeploy

**Alternative**: Deploy services separately (legacy):
```bash
cd deployment/legacy
./deploy_snowpark_container.sh  # Backend only
./deploy_frontend_spcs.sh       # Frontend only
```

**See [deployment/README.md](deployment/README.md) for complete deployment guide**

## 📁 Project Structure

```mermaid
graph LR
    A[bordereau/] --> B[backend/<br/>FastAPI backend]
    A --> C[frontend/<br/>React frontend]
    A --> D[bronze/<br/>Bronze layer SQL]
    A --> E[silver/<br/>Silver layer SQL]
    A --> F[deployment/<br/>Deployment scripts]
    A --> G[docker/<br/>Docker configs]
    A --> H[docs/<br/>Documentation hub]
    A --> I[sample_data/<br/>Sample files]
    
    style A fill:#f9f,stroke:#333,stroke-width:3px
    style B fill:#009688,stroke:#333,stroke-width:2px,color:#fff
    style C fill:#61dafb,stroke:#333,stroke-width:2px,color:#000
    style D fill:#cd7f32,stroke:#333,stroke-width:2px,color:#fff
    style E fill:#c0c0c0,stroke:#333,stroke-width:2px,color:#000
    style F fill:#ff9800,stroke:#333,stroke-width:2px,color:#fff
    style G fill:#2196f3,stroke:#333,stroke-width:2px,color:#fff
    style H fill:#4caf50,stroke:#333,stroke-width:2px,color:#fff
    style I fill:#9c27b0,stroke:#333,stroke-width:2px,color:#fff
```

## 📖 Documentation

| Document | Description |
|----------|-------------|
| **[Documentation Hub](docs/README.md)** | Complete documentation index |
| [Quick Start Guide](QUICK_START.md) | Get running in 10 minutes |
| [Implementation Log](docs/IMPLEMENTATION_LOG.md) | Complete implementation history |
| [User Guide](docs/USER_GUIDE.md) | Complete usage instructions |
| [Deployment Guide](deployment/README.md) | Full deployment documentation |
| [Quick Reference](deployment/QUICK_REFERENCE.md) | Quick deployment commands |
| [Backend README](backend/README.md) | Backend API documentation |
| [Migration Guide](MIGRATION_GUIDE.md) | Streamlit to React migration |

## 🛠️ Development

### Backend
```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload
```
**API Docs**: http://localhost:8000/api/docs

### Frontend
```bash
cd frontend
npm install && npm run dev
```
**Access**: http://localhost:3000

## 🔐 Authentication

The backend supports multiple authentication methods:

1. **Snow CLI** (Recommended for dev)
2. **PAT Token** (Recommended for prod)
3. **Keypair** (Most secure)
4. **Environment Variables**

See [backend/README.md](backend/README.md) for setup details.

## 🐛 Troubleshooting

**Backend issues**: Check Snowflake credentials, verify Python 3.10+  
**Frontend issues**: Clear cache, reinstall node_modules  
**Connection issues**: Verify Snow CLI connection with `snow connection test`

**For detailed troubleshooting, see [docs/README.md](docs/README.md)**

## 📝 License

Proprietary software. All rights reserved.

---

**Version**: 1.0 | **Last Updated**: January 19, 2026 | **Status**: ✅ Production Ready
