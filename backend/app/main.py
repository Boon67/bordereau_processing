"""
FastAPI Backend for Snowflake File Processing Pipeline
Provides REST API for React frontend
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import List, Optional
import logging

from app.api import bronze, silver, tpa
from app.services.snowflake_service import SnowflakeService
from app.config import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Snowflake Pipeline API",
    description="REST API for Snowflake File Processing Pipeline with Bronze and Silver layers",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(tpa.router, prefix="/api/tpas", tags=["TPA"])
app.include_router(bronze.router, prefix="/api/bronze", tags=["Bronze"])
app.include_router(silver.router, prefix="/api/silver", tags=["Silver"])

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Snowflake File Processing Pipeline API",
        "version": "1.0.0",
        "docs": "/api/docs"
    }

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Test Snowflake connection
        sf_service = SnowflakeService()
        result = sf_service.execute_query("SELECT CURRENT_VERSION()")
        return {
            "status": "healthy",
            "snowflake": "connected",
            "version": result[0][0] if result else "unknown"
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return JSONResponse(
            status_code=503,
            content={"status": "unhealthy", "error": str(e)}
        )

@app.on_event("startup")
async def startup_event():
    """Startup event handler"""
    logger.info("Starting Snowflake Pipeline API...")
    logger.info(f"Environment: {settings.ENVIRONMENT}")
    logger.info(f"Snowflake Account: {settings.SNOWFLAKE_ACCOUNT}")
    logger.info(f"Database: {settings.DATABASE_NAME}")

@app.on_event("shutdown")
async def shutdown_event():
    """Shutdown event handler"""
    logger.info("Shutting down Snowflake Pipeline API...")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
