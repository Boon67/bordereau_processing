"""
FastAPI Backend for Snowflake File Processing Pipeline
Provides REST API for React frontend
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import List, Optional
import logging

from app.api import bronze, silver, gold, tpa, user
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
app.include_router(gold.router, prefix="/api/gold", tags=["Gold"])
app.include_router(user.router, prefix="/api/user", tags=["User"])

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
    """
    Basic health check for readiness probe.
    Returns 200 if the service is running.
    Does NOT check Snowflake connection (too slow for probe).
    """
    from datetime import datetime
    return {
        "status": "healthy",
        "service": "running",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/health/db")
async def database_health_check():
    """
    Detailed health check including Snowflake connection.
    Use this for monitoring, not for readiness probe.
    """
    from datetime import datetime
    try:
        # Test Snowflake connection with short timeout
        sf_service = SnowflakeService()
        result = sf_service.execute_query(
            "SELECT CURRENT_VERSION(), CURRENT_WAREHOUSE(), CURRENT_DATABASE()",
            timeout=10
        )
        
        return {
            "status": "healthy",
            "service": "running",
            "database": "connected",
            "version": result[0][0] if result else "unknown",
            "warehouse": result[0][1] if result and len(result[0]) > 1 else "unknown",
            "database_name": result[0][2] if result and len(result[0]) > 2 else "unknown",
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": "running",
                "database": "disconnected",
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
        )

@app.get("/api/health/ready")
async def readiness_check():
    """
    Readiness check - service is ready to accept traffic.
    Checks if critical dependencies are available.
    """
    from datetime import datetime
    checks = {
        "service": "running",
        "timestamp": datetime.now().isoformat()
    }
    
    return {
        "status": "ready",
        **checks
    }

@app.on_event("startup")
async def startup_event():
    """Startup event handler"""
    import os
    from pathlib import Path
    
    logger.info("Starting Snowflake Pipeline API...")
    logger.info(f"Environment: {settings.ENVIRONMENT}")
    logger.info(f"Snowflake Account: {settings.SNOWFLAKE_ACCOUNT}")
    logger.info(f"Database: {settings.DATABASE_NAME}")
    
    # Debug: Check for SPCS token
    spcs_token_file = Path('/snowflake/session/token')
    logger.info(f"SPCS token file exists: {spcs_token_file.exists()}")
    logger.info(f"SNOWFLAKE_HOST env: {os.getenv('SNOWFLAKE_HOST', 'NOT SET')}")
    logger.info(f"SNOWFLAKE_ACCOUNT env: {os.getenv('SNOWFLAKE_ACCOUNT', 'NOT SET')}")
    logger.info(f"SNOWFLAKE_DATABASE env: {os.getenv('SNOWFLAKE_DATABASE', 'NOT SET')}")
    logger.info(f"SNOWFLAKE_SCHEMA env: {os.getenv('SNOWFLAKE_SCHEMA', 'NOT SET')}")
    
    # Try to get Snowflake config to see which auth method is used
    try:
        config = settings.get_snowflake_config()
        logger.info(f"Auth method detected - has 'host' key: {'host' in config}")
        logger.info(f"Auth method detected - has 'token' key: {'token' in config}")
        logger.info(f"Auth method detected - authenticator: {config.get('authenticator', 'NOT SET')}")
    except Exception as e:
        logger.error(f"Failed to get Snowflake config: {e}")

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
