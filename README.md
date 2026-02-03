# Bordereau Processing Pipeline

Healthcare claims data processing pipeline with **FastAPI**, **React**, and **Snowflake**.

## Quick Start

```bash
# 1. Install Snowflake CLI
pip install snowflake-cli-labs

# 2. Configure Snowflake connection
snow connection add

# 3. Deploy to Snowflake
cd deployment
./deploy.sh YOUR_CONNECTION

# 4. Start application
cd ..
./start.sh  # Linux/Mac
```

**Access**: http://localhost:3000

## Features

- **Bronze Layer**: Automated file ingestion with TPA isolation
- **Silver Layer**: ML/LLM-powered field mapping and transformation
- **Gold Layer**: Analytics-ready aggregations
- **Modern UI**: React + TypeScript with Ant Design

## Architecture

```
React Frontend (Port 3000) → FastAPI Backend (Port 8000) → Snowflake
                                                              ├─ Bronze (Raw)
                                                              ├─ Silver (Cleaned)
                                                              └─ Gold (Analytics)
```

## Deployment Options

**Local Dev**: `./start.sh`  
**Snowflake DB**: `cd deployment && ./deploy.sh CONNECTION`  
**SPCS Containers**: `./build_and_push_ghcr.sh && cd deployment && ./deploy_container.sh CONNECTION`

## Documentation

**[Complete Guide](docs/GUIDE.md)** - Usage, architecture, and troubleshooting

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection fails | `snow connection test` |
| Backend errors | Check credentials, verify Python 3.10+ |
| Frontend errors | Clear cache, `npm install` |
| Windows paths | Use Git Bash for scripts |

---

**Version**: 3.2 | **Updated**: February 2026 | **Status**: ✅ Production Ready
