# Bordereau Processing Pipeline

A modern, full-stack data processing pipeline built with FastAPI, React, and Snowflake for healthcare claims data processing.

## 🌟 Features

### Bronze Layer (Raw Data Ingestion)
- **File Upload**: Drag-and-drop interface for CSV and Excel files
- **Automatic Processing**: Task-based pipeline for file discovery and processing
- **Stage Management**: View and manage files across SRC, COMPLETED, ERROR, and ARCHIVE stages
- **Raw Data Viewer**: Browse and search raw data with statistics
- **Task Management**: Monitor and control Snowflake tasks

### Silver Layer (Data Transformation)
- **Target Schemas**: Define and manage target table structures
- **Field Mappings**: 
  - Manual mapping creation
  - ML-based auto-mapping
  - LLM-powered mapping (Snowflake Cortex)
  - Confidence scoring and approval workflow
- **Data Transformation**: Step-by-step wizard for Bronze → Silver transformation
- **Data Viewer**: Browse transformed data with quality metrics

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend (React)                      │
│  - Vite + TypeScript + Ant Design                      │
│  - Upload, Status, Stages, Data Viewer                 │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                   Backend (FastAPI)                      │
│  - REST API with Pydantic validation                    │
│  - Snowflake connector integration                      │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                  Snowflake Database                      │
│  - Bronze Layer: Raw data storage                       │
│  - Silver Layer: Transformed data                       │
│  - Tasks: Automated processing                          │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Python 3.10+
- Node.js 18+
- Snowflake account
- Snow CLI (recommended) or Snowflake credentials

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/Boon67/bordereau_processing.git
cd bordereau_processing
```

2. **Start the application**
```bash
./start.sh
```

This will:
- Set up Python virtual environment
- Install backend dependencies
- Install frontend dependencies
- Start both servers

3. **Access the application**
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/api/docs

## 🔐 Authentication

The backend supports multiple authentication methods (in priority order):

1. **Snow CLI** (Recommended)
   ```bash
   export SNOW_CONNECTION_NAME=DEPLOYMENT
   ```

2. **Configuration File** (`backend/config.toml`)
   ```toml
   [snowflake]
   account = "your-account"
   user = "your-user"
   # PAT Authentication
   token = "your-pat-token"
   # OR Keypair Authentication
   private_key_path = "/path/to/key.p8"
   ```

3. **Environment Variables**
   ```bash
   export SNOWFLAKE_ACCOUNT=your-account
   export SNOWFLAKE_USER=your-user
   export SNOWFLAKE_PASSWORD=your-password
   ```

See [backend/README.md](backend/README.md) for detailed authentication setup.

## 📁 Project Structure

```
bordereau_processing/
├── backend/                 # FastAPI backend
│   ├── app/
│   │   ├── api/            # API endpoints
│   │   │   ├── bronze.py   # Bronze layer endpoints
│   │   │   ├── silver.py   # Silver layer endpoints
│   │   │   └── tpa.py      # TPA management
│   │   ├── services/       # Business logic
│   │   │   └── snowflake_service.py
│   │   ├── config.py       # Configuration management
│   │   └── main.py         # FastAPI application
│   ├── requirements.txt
│   └── README.md
├── frontend/               # React frontend
│   ├── src/
│   │   ├── pages/         # Page components
│   │   │   ├── Bronze*.tsx
│   │   │   └── Silver*.tsx
│   │   ├── services/      # API client
│   │   │   └── api.ts
│   │   ├── types/         # TypeScript types
│   │   └── App.tsx
│   ├── package.json
│   └── vite.config.ts
├── start.sh               # Unified startup script
└── README.md
```

## 🛠️ Development

### Backend Development
```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload
```

### Frontend Development
```bash
cd frontend
npm run dev
```

### Running Tests
```bash
# Backend tests
cd backend
pytest

# Frontend tests
cd frontend
npm test
```

## 📊 Data Flow

1. **Upload**: Files uploaded to Bronze `@SRC` stage
2. **Discovery**: Task discovers new files and adds to queue
3. **Processing**: Files processed and raw data extracted
4. **Mapping**: Fields mapped from Bronze to Silver schemas
5. **Transformation**: Data transformed and loaded to Silver layer
6. **Validation**: Data quality checks applied

## 🔧 Configuration

### Backend Configuration
- `backend/config.py`: Application settings
- `backend/config.toml`: Snowflake credentials (optional)
- Environment variables for runtime configuration

### Frontend Configuration
- `frontend/vite.config.ts`: Vite and proxy settings
- `frontend/src/services/api.ts`: API client configuration

## 📖 API Documentation

Interactive API documentation available at:
- Swagger UI: http://localhost:8000/api/docs
- ReDoc: http://localhost:8000/api/redoc

### Key Endpoints

**Bronze Layer:**
- `POST /api/bronze/upload` - Upload files
- `GET /api/bronze/queue` - View processing queue
- `POST /api/bronze/discover` - Discover new files
- `POST /api/bronze/process` - Process queued files
- `GET /api/bronze/stages/{stage}` - List stage files
- `DELETE /api/bronze/stages/{stage}/files` - Delete stage file

**Silver Layer:**
- `GET /api/silver/schemas` - List target schemas
- `POST /api/silver/schemas` - Create schema column
- `GET /api/silver/mappings` - List field mappings
- `POST /api/silver/mappings` - Create manual mapping
- `POST /api/silver/mappings/auto-ml` - ML auto-mapping
- `POST /api/silver/mappings/auto-llm` - LLM auto-mapping
- `POST /api/silver/transform` - Execute transformation

## 🎨 UI Features

- **Modern Design**: Built with Ant Design components
- **Responsive Layout**: Works on desktop and tablet
- **Real-time Updates**: Live status monitoring
- **Drag & Drop**: Intuitive file upload
- **Data Visualization**: Statistics and charts
- **Search & Filter**: Powerful data exploration

## 🔒 Security

- Snowflake session token support
- Encrypted credential storage
- CORS configuration for API security
- Input validation with Pydantic
- SQL injection prevention

## 🐛 Troubleshooting

### Backend won't start
- Check Snowflake credentials
- Verify Python version (3.10+)
- Check `logs/backend.log`

### Frontend won't start
- Clear npm cache: `npm cache clean --force`
- Delete `node_modules` and reinstall
- Check `logs/frontend.log`

### TPAs not loading
- Verify backend is running: `curl http://localhost:8000/api/tpas`
- Check Snowflake connection
- Clear browser cache (Cmd+Shift+R)

## 📝 License

This project is proprietary software. All rights reserved.

## 👥 Contributing

This is a private project. For questions or issues, please contact the development team.

## 🙏 Acknowledgments

- **Snowflake** for the data platform
- **FastAPI** for the backend framework
- **React** and **Ant Design** for the frontend
- **Vite** for the build tool

---

**Built with ❤️ for healthcare data processing**
