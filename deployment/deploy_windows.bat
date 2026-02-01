@echo off
REM ============================================
REM Windows Batch Deployment Script
REM ============================================
REM This script deploys the Snowflake pipeline on Windows
REM without using bash - pure Windows commands
REM ============================================

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║     SNOWFLAKE FILE PROCESSING PIPELINE DEPLOYMENT         ║
echo ║                   Windows Version                         ║
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

REM Check if docker is installed (optional, for local testing)
where docker >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Docker is not installed (optional, only needed for local testing^)
    echo   Install: https://www.docker.com/products/docker-desktop
) else (
    echo [OK] Docker is installed
)

echo.

if "%MISSING_DEPS%"=="true" (
    echo [ERROR] Missing required dependencies. Please install them and try again.
    exit /b 1
)

REM Get connection name
set CONNECTION_NAME=%1
if "%CONNECTION_NAME%"=="" (
    echo Available connections:
    snow connection list
    echo.
    set /p CONNECTION_NAME="Enter connection name: "
)

echo Using connection: %CONNECTION_NAME%
echo.

REM Set configuration
set DATABASE=FILE_PROCESSING_PIPELINE
set WAREHOUSE=COMPUTE_WH
set BRONZE_SCHEMA=BRONZE
set SILVER_SCHEMA=SILVER
set GOLD_SCHEMA=GOLD

echo ═══════════════════════════════════════════════════════════
echo DEPLOYMENT CONFIGURATION
echo ═══════════════════════════════════════════════════════════
echo   Connection:    %CONNECTION_NAME%
echo   Database:      %DATABASE%
echo   Warehouse:     %WAREHOUSE%
echo   Bronze Schema: %BRONZE_SCHEMA%
echo   Silver Schema: %SILVER_SCHEMA%
echo   Gold Schema:   %GOLD_SCHEMA%
echo ═══════════════════════════════════════════════════════════
echo.

set /p CONFIRM="Continue with deployment? (y/n): "
if /i not "%CONFIRM%"=="y" (
    echo Deployment cancelled
    exit /b 0
)

echo.
echo [BRONZE] Deploying Bronze Layer...
echo.

cd ..\bronze

for %%f in (*.sql) do (
    echo Executing %%f...
    snow sql -f "%%f" --connection %CONNECTION_NAME% -D DATABASE_NAME=%DATABASE% -D BRONZE_SCHEMA_NAME=%BRONZE_SCHEMA% -D SILVER_SCHEMA_NAME=%SILVER_SCHEMA%
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to execute %%f
        exit /b 1
    )
)

echo [OK] Bronze layer deployed
echo.

echo [SILVER] Deploying Silver Layer...
echo.

cd ..\silver

for %%f in (*.sql) do (
    echo Executing %%f...
    snow sql -f "%%f" --connection %CONNECTION_NAME% -D DATABASE_NAME=%DATABASE% -D BRONZE_SCHEMA_NAME=%BRONZE_SCHEMA% -D SILVER_SCHEMA_NAME=%SILVER_SCHEMA%
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to execute %%f
        exit /b 1
    )
)

echo [OK] Silver layer deployed
echo.

echo [GOLD] Deploying Gold Layer...
echo.

cd ..\gold

for %%f in (*.sql) do (
    echo Executing %%f...
    snow sql -f "%%f" --connection %CONNECTION_NAME% -D DATABASE_NAME=%DATABASE% -D BRONZE_SCHEMA_NAME=%BRONZE_SCHEMA% -D SILVER_SCHEMA_NAME=%SILVER_SCHEMA% -D GOLD_SCHEMA_NAME=%GOLD_SCHEMA%
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to execute %%f
        exit /b 1
    )
)

echo [OK] Gold layer deployed
echo.

cd ..\deployment

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║                  DEPLOYMENT SUMMARY                       ║
echo ╠═══════════════════════════════════════════════════════════╣
echo ║  Connection: %CONNECTION_NAME%
echo ║  Database: %DATABASE%
echo ║  Bronze Layer: ✓ Deployed
echo ║  Silver Layer: ✓ Deployed
echo ║  Gold Layer: ✓ Deployed
echo ╚═══════════════════════════════════════════════════════════╝
echo.

echo [SUCCESS] Deployment completed!
echo.
echo Next steps:
echo   1. Upload sample data:
echo      snow stage put sample_data\claims_data\provider_a\*.csv @%DATABASE%.%BRONZE_SCHEMA%.SRC/provider_a/ --connection %CONNECTION_NAME%
echo.
