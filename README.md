# Bordereau Processing Pipeline

**AI-powered healthcare claims processing with medallion architecture**

FastAPI + React + Snowflake | ML/LLM Field Mapping | Multi-Tenant TPA Isolation

---

## 🚀 Quick Start

```bash
# 1. Install Snowflake CLI
pip install snowflake-cli-labs

# 2. Configure connection
snow connection add

# 3. Deploy to Snowflake
cd deployment && ./deploy.sh YOUR_CONNECTION

# 4. Start application
cd .. && ./start.sh
```

**Access**: http://localhost:3000

---

## ✨ Features

| Layer | Capability |
|-------|-----------|
| **Bronze** | Auto-ingestion, TPA isolation, file lifecycle management |
| **Silver** | ML/LLM auto-mapping, data quality rules, hybrid tables |
| **Gold** | Business analytics, member 360, provider metrics |
| **UI** | React + TypeScript, real-time updates, searchable filters |

---

## 📐 Architecture

```
┌──────────────┐
│ React (3000) │ TypeScript + Ant Design
└──────┬───────┘
       │ REST API
┌──────▼────────┐
│ FastAPI (8000)│ Python 3.11 + Uvicorn
└──────┬────────┘
       │ Snowflake Connector
┌──────▼─────────────────────┐
│ Snowflake Data Platform    │
│ ┌────────────────────────┐ │
│ │ Bronze (Raw)           │ │ Stages + VARIANT storage
│ └──────┬─────────────────┘ │
│ ┌──────▼─────────────────┐ │
│ │ Silver (Transformed)   │ │ Hybrid tables + indexes
│ └──────┬─────────────────┘ │
│ ┌──────▼─────────────────┐ │
│ │ Gold (Analytics)       │ │ Clustered aggregations
│ └────────────────────────┘ │
└────────────────────────────┘
```

**Multi-Tenancy**: Complete TPA isolation (stages, tables, mappings, rules)

---

## 📚 Documentation

- **[User Guide](docs/GUIDE.md)** - Complete usage instructions and workflows
- **[Architecture](docs/ARCHITECTURE.md)** - Technical design and data model
- **[Deployment](docs/GUIDE.md#deployment)** - Local, Snowflake DB, SPCS containers

---

## 🔧 Deployment Options

| Environment | Command |
|-------------|---------|
| **Local Dev** | `./start.sh` |
| **Snowflake DB** | `cd deployment && ./deploy.sh CONNECTION` |
| **SPCS Containers** | `./build_and_push_ghcr.sh && cd deployment && ./deploy_container.sh CONNECTION` |

---

## 🆘 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection fails | `snow connection test YOUR_CONNECTION` |
| Backend errors | Check `backend/config.example.toml`, verify Python 3.10+ |
| Frontend errors | `cd frontend && npm install && npm run dev` |
| Windows paths | Use Git Bash for deployment scripts |
| Tasks not running | `cd deployment && ./deploy.sh CONNECTION` (resume tasks) |

**Full troubleshooting guide**: [docs/GUIDE.md#troubleshooting](docs/GUIDE.md#troubleshooting)

---

## 🎯 Typical Workflow

1. **Add TPA** → Admin → TPA Management
2. **Upload Files** → Bronze → Upload (CSV/Excel)
3. **Auto-Map Fields** → Silver → Field Mappings → ML/LLM
4. **Transform Data** → Silver → Transform → Execute
5. **View Analytics** → Gold → Analytics Dashboard

---

## 🛠️ Technology Stack

**Frontend**: React 18, TypeScript 5, Ant Design 5, Vite 5  
**Backend**: Python 3.11, FastAPI, Uvicorn, Snowflake Connector  
**Database**: Snowflake (Hybrid Tables, Cortex AI, Snowpark)

---

**Version**: 3.3 | **Updated**: February 2026 | **Status**: ✅ Production Ready
