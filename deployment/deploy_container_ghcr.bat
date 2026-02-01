@echo off
REM ============================================
REM Deploy to Snowflake using GitHub Container Registry Images
REM ============================================

setlocal enabledelayedexpansion

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║     SNOWFLAKE CONTAINER DEPLOYMENT (GHCR)                 ║
echo ║     Using Pre-built Images from GitHub                    ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

echo Checking prerequisites...
echo.

set MISSING_DEPS=false

REM Check if snow CLI is installed
where snow >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Snowflake CLI is not installed
    echo   Install: pip install snowflake-cli-labs
    set MISSING_DEPS=true
) else (
    echo [OK] Snowflake CLI is installed
)

REM Check if jq is installed (optional but recommended)
where jq >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] jq is not installed (optional, but recommended for JSON parsing^)
    echo   Install with winget: winget install jqlang.jq
    echo   Or with Chocolatey: choco install jq
    echo   Or download: https://stedolan.github.io/jq/download/
) else (
    echo [OK] jq is installed
)

REM Check if docker is installed (optional, for image verification)
where docker >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Docker is not installed (optional, only needed for local image verification^)
    echo   Install: https://www.docker.com/products/docker-desktop
) else (
    echo [OK] Docker is installed
)

echo.

if "%MISSING_DEPS%"=="true" (
    echo [ERROR] Missing required dependencies. Please install them and try again.
    exit /b 1
)

REM Get parameters
set CONNECTION_NAME=%1
set GITHUB_USERNAME=%2
set VERSION=%3

if "%VERSION%"=="" set VERSION=latest

REM Get connection name
if "%CONNECTION_NAME%"=="" (
    echo Available Snowflake Connections:
    echo.
    snow connection list
    echo.
    set /p CONNECTION_NAME="Connection name: "
)

if "%CONNECTION_NAME%"=="" (
    echo [ERROR] Connection name is required
    exit /b 1
)

echo [OK] Using connection: %CONNECTION_NAME%

REM Get GitHub username
if "%GITHUB_USERNAME%"=="" (
    echo.
    set /p GITHUB_USERNAME="GitHub username (for ghcr.io/USERNAME/bordereau): "
)

if "%GITHUB_USERNAME%"=="" (
    echo [ERROR] GitHub username is required
    exit /b 1
)

echo [OK] Using GitHub username: %GITHUB_USERNAME%
echo [OK] Using version: %VERSION%

REM Set image URLs
set FRONTEND_IMAGE=ghcr.io/%GITHUB_USERNAME%/bordereau/frontend:%VERSION%
set BACKEND_IMAGE=ghcr.io/%GITHUB_USERNAME%/bordereau/backend:%VERSION%

echo.
echo Images to deploy:
echo   Frontend: %FRONTEND_IMAGE%
echo   Backend:  %BACKEND_IMAGE%
echo.

REM Configuration
set DATABASE=BORDEREAU_PROCESSING_PIPELINE
set WAREHOUSE=COMPUTE_WH
set COMPUTE_POOL=BORDEREAU_POOL
set SERVICE_NAME=BORDEREAU_APP
set IMAGE_REPO=BORDEREAU_IMAGES

echo ═══════════════════════════════════════════════════════════
echo DEPLOYMENT CONFIGURATION
echo ═══════════════════════════════════════════════════════════
echo   Connection:     %CONNECTION_NAME%
echo   Database:       %DATABASE%
echo   Warehouse:      %WAREHOUSE%
echo   Compute Pool:   %COMPUTE_POOL%
echo   Service Name:   %SERVICE_NAME%
echo   Image Repo:     %IMAGE_REPO%
echo   GitHub User:    %GITHUB_USERNAME%
echo   Version:        %VERSION%
echo ═══════════════════════════════════════════════════════════
echo.

set /p CONFIRM="Continue with deployment? (y/n): "
if /i not "%CONFIRM%"=="y" (
    echo Deployment cancelled
    exit /b 0
)

echo.
echo [1/5] Setting up image repository...

snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; USE WAREHOUSE %WAREHOUSE%; CREATE IMAGE REPOSITORY IF NOT EXISTS %IMAGE_REPO%; SHOW IMAGE REPOSITORIES LIKE '%IMAGE_REPO%';"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to create image repository
    exit /b 1
)

echo [OK] Image repository ready
echo.

REM Check if images are private
echo Checking if images are public or private...
echo.
echo If your images are PRIVATE, you'll need a GitHub token.
echo To create a token:
echo   1. Go to GitHub Settings - Developer settings - Personal access tokens
echo   2. Create token with 'read:packages' scope
echo   3. Copy the token
echo.
set /p GITHUB_TOKEN="GitHub Token (or press Enter if images are public): "

if not "%GITHUB_TOKEN%"=="" (
    echo.
    echo [2/5] Setting up authentication...
    
    snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; CREATE OR REPLACE SECRET GHCR_TOKEN TYPE = GENERIC_STRING SECRET_STRING = '%GITHUB_TOKEN%'; GRANT USAGE ON SECRET GHCR_TOKEN TO ROLE %DATABASE%_ADMIN;"
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to create secret
        exit /b 1
    )
    
    echo [OK] Authentication configured
    set USE_AUTH=true
) else (
    echo [2/5] Skipping authentication (assuming public images)
    set USE_AUTH=false
)

echo.
echo [3/5] Pulling images to Snowflake...
echo This may take several minutes...
echo.

if "%USE_AUTH%"=="true" (
    REM Pull with authentication
    echo Pulling frontend image with authentication...
    snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; CALL SYSTEM$REGISTRY_PULL_IMAGE('%IMAGE_REPO%', '%FRONTEND_IMAGE%', '%GITHUB_USERNAME%', SECRET GHCR_TOKEN);"
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to pull frontend image
        exit /b 1
    )
    
    echo Pulling backend image with authentication...
    snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; CALL SYSTEM$REGISTRY_PULL_IMAGE('%IMAGE_REPO%', '%BACKEND_IMAGE%', '%GITHUB_USERNAME%', SECRET GHCR_TOKEN);"
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to pull backend image
        exit /b 1
    )
) else (
    REM Pull without authentication
    echo Pulling frontend image...
    snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; CALL SYSTEM$REGISTRY_PULL_IMAGE('%IMAGE_REPO%', '%FRONTEND_IMAGE%');"
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to pull frontend image
        echo Hint: If images are private, run again and provide GitHub token
        exit /b 1
    )
    
    echo Pulling backend image...
    snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; CALL SYSTEM$REGISTRY_PULL_IMAGE('%IMAGE_REPO%', '%BACKEND_IMAGE%');"
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to pull backend image
        exit /b 1
    )
)

echo [OK] Images pulled successfully
echo.

echo [4/5] Verifying images...
snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; SELECT image_name, image_tag, created_on, size_bytes / 1024 / 1024 AS size_mb FROM TABLE(SYSTEM$REGISTRY_LIST_IMAGES('%IMAGE_REPO%')) WHERE image_name LIKE '%%bordereau%%' ORDER BY created_on DESC;"

echo.
echo [5/5] Deploying service...

REM Drop existing service if it exists
snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; DROP SERVICE IF EXISTS %SERVICE_NAME%;"

REM Wait for cleanup
timeout /t 5 /nobreak >nul

REM Create service
echo Creating service...

snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; USE WAREHOUSE %WAREHOUSE%; CREATE SERVICE %SERVICE_NAME% IN COMPUTE POOL %COMPUTE_POOL% FROM SPECIFICATION $$ spec: containers: - name: frontend image: /%IMAGE_REPO%/%FRONTEND_IMAGE% env: REACT_APP_API_URL: http://localhost:8000 readinessProbe: port: 80 path: / - name: backend image: /%IMAGE_REPO%/%BACKEND_IMAGE% env: SNOWFLAKE_ACCOUNT: !ref SNOWFLAKE_ACCOUNT SNOWFLAKE_USER: !ref SNOWFLAKE_USER SNOWFLAKE_PASSWORD: !ref SNOWFLAKE_PASSWORD SNOWFLAKE_WAREHOUSE: %WAREHOUSE% SNOWFLAKE_DATABASE: %DATABASE% SNOWFLAKE_ROLE: SYSADMIN SNOWFLAKE_BRONZE_SCHEMA: BRONZE SNOWFLAKE_SILVER_SCHEMA: SILVER SNOWFLAKE_GOLD_SCHEMA: GOLD readinessProbe: port: 8000 path: /health endpoints: - name: frontend port: 80 public: true $$ MIN_INSTANCES = 1 MAX_INSTANCES = 1;"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to create service
    exit /b 1
)

echo [OK] Service created
echo.

echo Waiting for service to start...
timeout /t 10 /nobreak >nul

echo.
echo Service Status:
snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; SELECT name, status, compute_pool, created_on FROM TABLE(INFORMATION_SCHEMA.SERVICES) WHERE name = '%SERVICE_NAME%';"

echo.
echo Service Endpoints:
snow sql --connection %CONNECTION_NAME% -q "USE ROLE SYSADMIN; USE DATABASE %DATABASE%; SHOW ENDPOINTS IN SERVICE %SERVICE_NAME%;"

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║              DEPLOYMENT SUMMARY                           ║
echo ╠═══════════════════════════════════════════════════════════╣
echo ║  Service: %SERVICE_NAME%
echo ║  Images: GHCR (%VERSION%)
echo ║  Frontend: %FRONTEND_IMAGE%
echo ║  Backend:  %BACKEND_IMAGE%
echo ╚═══════════════════════════════════════════════════════════╝
echo.

echo [SUCCESS] Deployment completed!
echo.
echo Next steps:
echo   1. Check service status:
echo      snow sql --connection %CONNECTION_NAME% -q "SHOW SERVICES LIKE '%SERVICE_NAME%'"
echo.
echo   2. Get service endpoint:
echo      snow sql --connection %CONNECTION_NAME% -q "SHOW ENDPOINTS IN SERVICE %SERVICE_NAME%"
echo.
echo   3. View service logs:
echo      snow sql --connection %CONNECTION_NAME% -q "CALL SYSTEM$GET_SERVICE_LOGS('%SERVICE_NAME%', 0, 'frontend')"
echo.

endlocal
