@echo off
REM ============================================
REM Container Services Deployment Script
REM ============================================
REM Deploy Frontend + Backend to Snowpark Container Services
REM Backend is internal-only (no public endpoint)
REM Frontend proxies API requests to backend
REM ============================================

setlocal enabledelayedexpansion

REM Get script directory and project root
set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fi"
cd /d "%PROJECT_ROOT%"

REM Configuration
if "%SNOWFLAKE_ACCOUNT%"=="" set "SNOWFLAKE_ACCOUNT=SFSENORTHAMERICA-TBOON_AWS2"
if "%SNOWFLAKE_USER%"=="" set "SNOWFLAKE_USER=DEMO_SVC"
if "%SNOWFLAKE_ROLE%"=="" set "SNOWFLAKE_ROLE=BORDEREAU_PROCESSING_PIPELINE_ADMIN"
if "%SNOWFLAKE_WAREHOUSE%"=="" set "SNOWFLAKE_WAREHOUSE=COMPUTE_WH"
if "%DATABASE_NAME%"=="" set "DATABASE_NAME=BORDEREAU_PROCESSING_PIPELINE"
if "%SCHEMA_NAME%"=="" set "SCHEMA_NAME=PUBLIC"

REM Service configuration
if "%SERVICE_NAME%"=="" set "SERVICE_NAME=BORDEREAU_APP"
if "%COMPUTE_POOL_NAME%"=="" set "COMPUTE_POOL_NAME=BORDEREAU_COMPUTE_POOL"
if "%REPOSITORY_NAME%"=="" set "REPOSITORY_NAME=BORDEREAU_REPOSITORY"

REM Image configuration
if "%BACKEND_IMAGE_NAME%"=="" set "BACKEND_IMAGE_NAME=bordereau_backend"
if "%FRONTEND_IMAGE_NAME%"=="" set "FRONTEND_IMAGE_NAME=bordereau_frontend"
if "%IMAGE_TAG%"=="" set "IMAGE_TAG=latest"

echo.
echo ================================================================
echo   Unified Service Deployment (Frontend + Backend)
echo ================================================================
echo.
echo   Service:         %SERVICE_NAME%
echo   Account:         %SNOWFLAKE_ACCOUNT%
echo   Database:        %DATABASE_NAME%
echo   Compute Pool:    %COMPUTE_POOL_NAME%
echo   Repository:      %REPOSITORY_NAME%
echo.
echo   Architecture:
echo     - Frontend (nginx) - Public endpoint on port 80
echo     - Backend (FastAPI) - Internal only on port 8000
echo     - Frontend proxies /api/* to backend
echo.
echo ================================================================
echo.

REM Validate prerequisites
echo [1/10] Validating prerequisites...

where snow >nul 2>&1
if errorlevel 1 (
    echo [ERROR] snow CLI not found
    echo Please install Snowflake CLI
    exit /b 1
)

where docker >nul 2>&1
if errorlevel 1 (
    echo [ERROR] docker not found
    echo Please install Docker Desktop
    exit /b 1
)

where jq >nul 2>&1
if errorlevel 1 (
    echo [WARNING] jq not found (optional but recommended)
)

snow connection test --connection DEPLOYMENT >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Snowflake connection test failed
    exit /b 1
)

echo [SUCCESS] Prerequisites validated

REM Create compute pool
echo [2/10] Creating compute pool...
call :create_compute_pool
if errorlevel 1 exit /b 1

REM Create image repository
echo [3/10] Creating image repository...
call :create_image_repository
if errorlevel 1 exit /b 1

REM Get repository URL
echo [4/10] Getting repository URL...
call :get_repository_url
if errorlevel 1 exit /b 1

REM Docker login
echo [5/10] Logging into Docker registry...
snow spcs image-registry login --connection DEPLOYMENT
if errorlevel 1 (
    echo [ERROR] Docker login failed
    exit /b 1
)
echo [SUCCESS] Docker login successful

REM Build backend image
echo [6/10] Building backend Docker image...
call :build_backend_image
if errorlevel 1 exit /b 1

REM Build frontend image
echo [7/10] Building frontend Docker image...
call :build_frontend_image
if errorlevel 1 exit /b 1

REM Push images
echo [8/10] Pushing Docker images...
call :push_images
if errorlevel 1 exit /b 1

REM Create service specification
echo [9/10] Creating unified service specification...
call :create_service_spec
if errorlevel 1 exit /b 1

REM Deploy service
echo [10/10] Deploying unified service...
call :deploy_service
if errorlevel 1 exit /b 1

REM Get service endpoint
call :get_service_endpoint

REM Print summary
call :print_summary

exit /b 0

REM ============================================
REM Functions
REM ============================================

:create_compute_pool
snow sql -q "SHOW COMPUTE POOLS LIKE '%COMPUTE_POOL_NAME%'" --connection DEPLOYMENT --format json >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Compute pool already exists: %COMPUTE_POOL_NAME%
    exit /b 0
)

echo [INFO] Creating compute pool: %COMPUTE_POOL_NAME%

echo USE ROLE %SNOWFLAKE_ROLE%; > %TEMP%\create_pool.sql
echo USE DATABASE %DATABASE_NAME%; >> %TEMP%\create_pool.sql
echo USE SCHEMA %SCHEMA_NAME%; >> %TEMP%\create_pool.sql
echo CREATE COMPUTE POOL %COMPUTE_POOL_NAME% >> %TEMP%\create_pool.sql
echo     MIN_NODES = 1 >> %TEMP%\create_pool.sql
echo     MAX_NODES = 3 >> %TEMP%\create_pool.sql
echo     INSTANCE_FAMILY = CPU_X64_XS >> %TEMP%\create_pool.sql
echo     AUTO_RESUME = TRUE >> %TEMP%\create_pool.sql
echo     AUTO_SUSPEND_SECS = 3600 >> %TEMP%\create_pool.sql
echo     COMMENT = 'Compute pool for Bordereau unified service'; >> %TEMP%\create_pool.sql

snow sql -f %TEMP%\create_pool.sql --connection DEPLOYMENT >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to create compute pool
    exit /b 1
)

del %TEMP%\create_pool.sql 2>nul
echo [SUCCESS] Compute pool created: %COMPUTE_POOL_NAME%
exit /b 0

:create_image_repository
snow sql -q "SHOW IMAGE REPOSITORIES LIKE '%REPOSITORY_NAME%'" --connection DEPLOYMENT --format json >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Image repository already exists: %REPOSITORY_NAME%
    exit /b 0
)

echo [INFO] Creating image repository: %REPOSITORY_NAME%

echo USE ROLE %SNOWFLAKE_ROLE%; > %TEMP%\create_repo.sql
echo USE DATABASE %DATABASE_NAME%; >> %TEMP%\create_repo.sql
echo USE SCHEMA %SCHEMA_NAME%; >> %TEMP%\create_repo.sql
echo CREATE IMAGE REPOSITORY %REPOSITORY_NAME% >> %TEMP%\create_repo.sql
echo     COMMENT = 'Container images for Bordereau unified service'; >> %TEMP%\create_repo.sql

snow sql -f %TEMP%\create_repo.sql --connection DEPLOYMENT >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to create image repository
    exit /b 1
)

del %TEMP%\create_repo.sql 2>nul
echo [SUCCESS] Image repository created: %REPOSITORY_NAME%
exit /b 0

:get_repository_url
for /f "tokens=*" %%i in ('snow spcs image-repository url "%REPOSITORY_NAME%" --connection DEPLOYMENT --database "%DATABASE_NAME%" --schema "%SCHEMA_NAME%" 2^>nul') do set "REPOSITORY_URL=%%i"

REM Convert to lowercase
for %%L in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    set "REPOSITORY_URL=!REPOSITORY_URL:%%L=%%L!"
)

if "%REPOSITORY_URL%"=="" (
    echo [ERROR] Failed to get repository URL
    exit /b 1
)

echo [SUCCESS] Repository URL: %REPOSITORY_URL%
exit /b 0

:build_backend_image
set "full_image_name=%REPOSITORY_URL%/%BACKEND_IMAGE_NAME%:%IMAGE_TAG%"

cd /d "%PROJECT_ROOT%"

if not exist "docker\Dockerfile.backend" (
    echo [ERROR] docker\Dockerfile.backend not found
    exit /b 1
)

echo [INFO] Building backend image: %full_image_name%
echo [INFO] Build context: %PROJECT_ROOT%

docker build --platform linux/amd64 -f docker\Dockerfile.backend -t "%full_image_name%" -t "%BACKEND_IMAGE_NAME%:%IMAGE_TAG%" .
if errorlevel 1 (
    echo [ERROR] Backend Docker build failed
    exit /b 1
)

echo [SUCCESS] Backend image built
exit /b 0

:build_frontend_image
set "full_image_name=%REPOSITORY_URL%/%FRONTEND_IMAGE_NAME%:%IMAGE_TAG%"

REM Create nginx config
echo [INFO] Creating nginx configuration...
echo server { > %TEMP%\nginx-unified.conf
echo     listen 80; >> %TEMP%\nginx-unified.conf
echo     server_name _; >> %TEMP%\nginx-unified.conf
echo     root /usr/share/nginx/html; >> %TEMP%\nginx-unified.conf
echo     index index.html; >> %TEMP%\nginx-unified.conf
echo     location / { >> %TEMP%\nginx-unified.conf
echo         try_files $uri $uri/ /index.html; >> %TEMP%\nginx-unified.conf
echo     } >> %TEMP%\nginx-unified.conf
echo     location /api/ { >> %TEMP%\nginx-unified.conf
echo         proxy_pass http://localhost:8000/api/; >> %TEMP%\nginx-unified.conf
echo         proxy_http_version 1.1; >> %TEMP%\nginx-unified.conf
echo         proxy_set_header Upgrade $http_upgrade; >> %TEMP%\nginx-unified.conf
echo         proxy_set_header Connection 'upgrade'; >> %TEMP%\nginx-unified.conf
echo         proxy_set_header Host $host; >> %TEMP%\nginx-unified.conf
echo         proxy_cache_bypass $http_upgrade; >> %TEMP%\nginx-unified.conf
echo     } >> %TEMP%\nginx-unified.conf
echo } >> %TEMP%\nginx-unified.conf

REM Create Dockerfile
echo FROM node:18-alpine AS builder > %PROJECT_ROOT%\Dockerfile.frontend.unified
echo WORKDIR /app >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo COPY frontend/package.json frontend/package-lock.json* ./ >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo RUN npm ci >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo COPY frontend/ . >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo RUN npm run build >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo FROM nginx:alpine >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo COPY --from=builder /app/dist /usr/share/nginx/html >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo COPY nginx-unified.conf /etc/nginx/conf.d/default.conf >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo EXPOSE 80 >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo HEALTHCHECK --interval=30s --timeout=3s CMD wget --quiet --tries=1 --spider http://localhost/ ^|^| exit 1 >> %PROJECT_ROOT%\Dockerfile.frontend.unified
echo CMD ["nginx", "-g", "daemon off;"] >> %PROJECT_ROOT%\Dockerfile.frontend.unified

copy %TEMP%\nginx-unified.conf %PROJECT_ROOT%\nginx-unified.conf >nul

echo [INFO] Building frontend image: %full_image_name%
echo [INFO] Build context: %PROJECT_ROOT%

cd /d "%PROJECT_ROOT%"

docker build --platform linux/amd64 -f Dockerfile.frontend.unified -t "%full_image_name%" -t "%FRONTEND_IMAGE_NAME%:%IMAGE_TAG%" .
if errorlevel 1 (
    echo [ERROR] Frontend Docker build failed
    del %PROJECT_ROOT%\nginx-unified.conf 2>nul
    del %PROJECT_ROOT%\Dockerfile.frontend.unified 2>nul
    exit /b 1
)

REM Cleanup
del %PROJECT_ROOT%\nginx-unified.conf 2>nul
del %PROJECT_ROOT%\Dockerfile.frontend.unified 2>nul

echo [SUCCESS] Frontend image built
exit /b 0

:push_images
set "backend_image=%REPOSITORY_URL%/%BACKEND_IMAGE_NAME%:%IMAGE_TAG%"
set "frontend_image=%REPOSITORY_URL%/%FRONTEND_IMAGE_NAME%:%IMAGE_TAG%"

echo [INFO] Pushing backend image...
docker push "%backend_image%"
if errorlevel 1 (
    echo [ERROR] Backend image push failed
    exit /b 1
)

echo [INFO] Pushing frontend image...
docker push "%frontend_image%"
if errorlevel 1 (
    echo [ERROR] Frontend image push failed
    exit /b 1
)

echo [SUCCESS] Images pushed successfully
exit /b 0

:create_service_spec
echo spec: > %TEMP%\unified_service_spec.yaml
echo   containers: >> %TEMP%\unified_service_spec.yaml
echo   - name: backend >> %TEMP%\unified_service_spec.yaml
echo     image: /%DATABASE_NAME%/%SCHEMA_NAME%/%REPOSITORY_NAME%/%BACKEND_IMAGE_NAME%:%IMAGE_TAG% >> %TEMP%\unified_service_spec.yaml
echo     env: >> %TEMP%\unified_service_spec.yaml
echo       ENVIRONMENT: production >> %TEMP%\unified_service_spec.yaml
echo       SNOWFLAKE_ACCOUNT: %SNOWFLAKE_ACCOUNT% >> %TEMP%\unified_service_spec.yaml
echo       SNOWFLAKE_USER: %SNOWFLAKE_USER% >> %TEMP%\unified_service_spec.yaml
echo       SNOWFLAKE_ROLE: %SNOWFLAKE_ROLE% >> %TEMP%\unified_service_spec.yaml
echo       SNOWFLAKE_WAREHOUSE: %SNOWFLAKE_WAREHOUSE% >> %TEMP%\unified_service_spec.yaml
echo       DATABASE_NAME: %DATABASE_NAME% >> %TEMP%\unified_service_spec.yaml
echo       BRONZE_SCHEMA_NAME: BRONZE >> %TEMP%\unified_service_spec.yaml
echo       SILVER_SCHEMA_NAME: SILVER >> %TEMP%\unified_service_spec.yaml
echo     resources: >> %TEMP%\unified_service_spec.yaml
echo       requests: >> %TEMP%\unified_service_spec.yaml
echo         cpu: 0.6 >> %TEMP%\unified_service_spec.yaml
echo         memory: 2Gi >> %TEMP%\unified_service_spec.yaml
echo       limits: >> %TEMP%\unified_service_spec.yaml
echo         cpu: "2" >> %TEMP%\unified_service_spec.yaml
echo         memory: 4Gi >> %TEMP%\unified_service_spec.yaml
echo     readinessProbe: >> %TEMP%\unified_service_spec.yaml
echo       port: 8000 >> %TEMP%\unified_service_spec.yaml
echo       path: /api/health >> %TEMP%\unified_service_spec.yaml
echo   - name: frontend >> %TEMP%\unified_service_spec.yaml
echo     image: /%DATABASE_NAME%/%SCHEMA_NAME%/%REPOSITORY_NAME%/%FRONTEND_IMAGE_NAME%:%IMAGE_TAG% >> %TEMP%\unified_service_spec.yaml
echo     env: >> %TEMP%\unified_service_spec.yaml
echo       NGINX_WORKER_PROCESSES: "2" >> %TEMP%\unified_service_spec.yaml
echo     resources: >> %TEMP%\unified_service_spec.yaml
echo       requests: >> %TEMP%\unified_service_spec.yaml
echo         cpu: 0.4 >> %TEMP%\unified_service_spec.yaml
echo         memory: 1Gi >> %TEMP%\unified_service_spec.yaml
echo       limits: >> %TEMP%\unified_service_spec.yaml
echo         cpu: 1 >> %TEMP%\unified_service_spec.yaml
echo         memory: 2Gi >> %TEMP%\unified_service_spec.yaml
echo     readinessProbe: >> %TEMP%\unified_service_spec.yaml
echo       port: 80 >> %TEMP%\unified_service_spec.yaml
echo       path: / >> %TEMP%\unified_service_spec.yaml
echo   endpoints: >> %TEMP%\unified_service_spec.yaml
echo   - name: app >> %TEMP%\unified_service_spec.yaml
echo     port: 80 >> %TEMP%\unified_service_spec.yaml
echo     public: true >> %TEMP%\unified_service_spec.yaml

echo [SUCCESS] Service specification created
exit /b 0

:deploy_service
echo [INFO] Creating stage for service specifications...
snow sql -q "USE DATABASE %DATABASE_NAME%; USE SCHEMA %SCHEMA_NAME%; CREATE STAGE IF NOT EXISTS SERVICE_SPECS COMMENT = 'Stage for Snowpark Container Service specifications';" --connection DEPLOYMENT >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to create stage
    exit /b 1
)

echo [INFO] Uploading service specification...
snow sql -q "USE DATABASE %DATABASE_NAME%; USE SCHEMA %SCHEMA_NAME%; PUT file://%TEMP:\=/%/unified_service_spec.yaml @SERVICE_SPECS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" --connection DEPLOYMENT >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to upload service specification
    exit /b 1
)

echo [INFO] Checking if service exists...
snow spcs service list --database "%DATABASE_NAME%" --schema "%SCHEMA_NAME%" --format json 2>nul | findstr /C:"%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Service '%SERVICE_NAME%' already exists. Using suspend/upgrade/resume workflow...
    
    echo [INFO] Suspending service...
    snow spcs service suspend "%SERVICE_NAME%" --database "%DATABASE_NAME%" --schema "%SCHEMA_NAME%"
    if errorlevel 1 (
        echo [ERROR] Failed to suspend service
        exit /b 1
    )
    echo [SUCCESS] Service suspended
    
    timeout /t 5 /nobreak >nul
    
    echo [INFO] Upgrading service with new images...
    snow spcs service upgrade "%SERVICE_NAME%" --database "%DATABASE_NAME%" --schema "%SCHEMA_NAME%" --spec-path %TEMP%\unified_service_spec.yaml
    if errorlevel 1 (
        echo [ERROR] Failed to upgrade service
        exit /b 1
    )
    echo [SUCCESS] Service upgraded
    
    echo [INFO] Resuming service...
    snow spcs service resume "%SERVICE_NAME%" --database "%DATABASE_NAME%" --schema "%SCHEMA_NAME%"
    if errorlevel 1 (
        echo [ERROR] Failed to resume service
        exit /b 1
    )
    echo [SUCCESS] Service resumed
    
    timeout /t 10 /nobreak >nul
) else (
    echo [INFO] Creating new service '%SERVICE_NAME%'...
    
    echo USE ROLE %SNOWFLAKE_ROLE%; > %TEMP%\create_service.sql
    echo USE DATABASE %DATABASE_NAME%; >> %TEMP%\create_service.sql
    echo USE SCHEMA %SCHEMA_NAME%; >> %TEMP%\create_service.sql
    echo CREATE SERVICE %SERVICE_NAME% >> %TEMP%\create_service.sql
    echo     IN COMPUTE POOL %COMPUTE_POOL_NAME% >> %TEMP%\create_service.sql
    echo     FROM @SERVICE_SPECS >> %TEMP%\create_service.sql
    echo     SPECIFICATION_FILE = 'unified_service_spec.yaml' >> %TEMP%\create_service.sql
    echo     MIN_INSTANCES = 1 >> %TEMP%\create_service.sql
    echo     MAX_INSTANCES = 3 >> %TEMP%\create_service.sql
    echo     COMMENT = 'Bordereau unified service (Frontend + Backend)'; >> %TEMP%\create_service.sql
    
    snow sql -f %TEMP%\create_service.sql --connection DEPLOYMENT
    if errorlevel 1 (
        echo [ERROR] Failed to create service
        exit /b 1
    )
    echo [SUCCESS] Service created: %SERVICE_NAME%
)

exit /b 0

:get_service_endpoint
echo.
echo [INFO] Getting service endpoint...

set "SERVICE_ENDPOINT="
set "attempt=1"
set "max_attempts=10"

:endpoint_loop
if %attempt% gtr %max_attempts% goto endpoint_done

for /f "tokens=*" %%i in ('snow spcs service list --database "%DATABASE_NAME%" --schema "%SCHEMA_NAME%" --format json 2^>nul ^| jq -r ".[] | select(.name == \"%SERVICE_NAME%\") | .dns_name // empty" 2^>nul') do set "dns_name=%%i"

if not "%dns_name%"=="" (
    if not "%dns_name%"=="null" (
        set "SERVICE_ENDPOINT=https://%dns_name%"
        echo [SUCCESS] Service endpoint: !SERVICE_ENDPOINT!
        exit /b 0
    )
)

if %attempt% lss %max_attempts% (
    echo [INFO] Endpoint not ready, waiting... (attempt %attempt%/%max_attempts%)
    timeout /t 10 /nobreak >nul
)

set /a attempt+=1
goto endpoint_loop

:endpoint_done
echo [WARNING] Endpoint not available yet. Service may still be starting.
echo [INFO] Check status with: cd deployment ^&^& manage_services.bat status
exit /b 0

:print_summary
echo.
echo ================================================================
echo   DEPLOYMENT SUCCESSFUL!
echo ================================================================
echo.
echo   [OK] Unified Service Deployed
echo      - Frontend + Backend in single service
echo      - Backend is internal-only (no public endpoint)
echo      - Frontend proxies /api/* to backend
echo.
echo ================================================================
echo   ENDPOINT
echo ================================================================
echo.
if not "%SERVICE_ENDPOINT%"=="" (
    echo   Application (Frontend):
    echo     %SERVICE_ENDPOINT%
    echo.
    echo   API (via Frontend proxy):
    echo     %SERVICE_ENDPOINT%/api/health
    echo.
    echo   Test:
    echo     curl %SERVICE_ENDPOINT%/api/health
) else (
    echo   Endpoint provisioning in progress...
    echo   Check status: manage_services.bat status
)
echo.
echo ================================================================
echo   MANAGEMENT
echo ================================================================
echo.
echo   Check status:
echo     cd deployment
echo     manage_services.bat status
echo.
echo ================================================================
echo.
exit /b 0
