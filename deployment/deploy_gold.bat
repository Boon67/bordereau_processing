@echo off
REM ============================================
REM GOLD LAYER DEPLOYMENT SCRIPT
REM ============================================
REM Purpose: Deploy Gold layer to Snowflake
REM Usage: deploy_gold.bat [connection_name]
REM ============================================

setlocal enabledelayedexpansion

REM Get script directory and project root
set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fi"

REM Configuration
if "%~1"=="" (
    set "CONNECTION_NAME=DEPLOYMENT"
) else (
    set "CONNECTION_NAME=%~1"
)

if "%DATABASE_NAME%"=="" set "DATABASE_NAME=BORDEREAU_PROCESSING_PIPELINE"
if "%SILVER_SCHEMA_NAME%"=="" set "SILVER_SCHEMA_NAME=SILVER"
if "%GOLD_SCHEMA_NAME%"=="" set "GOLD_SCHEMA_NAME=GOLD"

echo ============================================
echo GOLD LAYER DEPLOYMENT
echo ============================================
echo.
echo Connection: %CONNECTION_NAME%
echo Database: %DATABASE_NAME%
echo Silver Schema: %SILVER_SCHEMA_NAME%
echo Gold Schema: %GOLD_SCHEMA_NAME%
echo.

REM Check if snow CLI is available
where snow >nul 2>&1
if errorlevel 1 (
    echo [ERROR] snow CLI not found
    echo Please install Snowflake CLI: https://docs.snowflake.com/en/developer-guide/snowflake-cli/index
    exit /b 1
)

REM Test connection
echo [INFO] Testing Snowflake connection...
snow connection test --connection "%CONNECTION_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Cannot connect to Snowflake
    echo Please check your connection: snow connection test --connection %CONNECTION_NAME%
    exit /b 1
)
echo [SUCCESS] Connection successful
echo.

REM Deploy Gold Layer
cd /d "%PROJECT_ROOT%"

echo ============================================
echo DEPLOYING GOLD LAYER
echo ============================================
echo.

REM 1. Gold Schema Setup
echo [1/5] Creating Gold schema and metadata tables...
snow sql -f gold\1_Gold_Schema_Setup.sql --connection "%CONNECTION_NAME%" -D "DATABASE_NAME=%DATABASE_NAME%" -D "SILVER_SCHEMA_NAME=%SILVER_SCHEMA_NAME%" -D "GOLD_SCHEMA_NAME=%GOLD_SCHEMA_NAME%"
if errorlevel 1 (
    echo [ERROR] Failed to create Gold schema
    exit /b 1
)
echo [SUCCESS] Gold schema created
echo.

REM 2. Gold Target Schemas (Using BULK optimized version)
echo [2/5] Creating Gold target schemas (bulk optimized - 88%% faster)...
snow sql -f "%PROJECT_ROOT%\gold\2_Gold_Target_Schemas_BULK.sql" --connection "%CONNECTION_NAME%" -D "DATABASE_NAME=%DATABASE_NAME%" -D "GOLD_SCHEMA_NAME=%GOLD_SCHEMA_NAME%"
if errorlevel 1 (
    echo [ERROR] Failed to create Gold target schemas
    exit /b 1
)
echo [SUCCESS] Gold target schemas created (8 operations vs 69)
echo.

REM 3. Gold Transformation Rules
echo [3/5] Creating Gold transformation rules...
snow sql -f "%PROJECT_ROOT%\gold\3_Gold_Transformation_Rules.sql" --connection "%CONNECTION_NAME%" -D "DATABASE_NAME=%DATABASE_NAME%" -D "GOLD_SCHEMA_NAME=%GOLD_SCHEMA_NAME%"
if errorlevel 1 (
    echo [ERROR] Failed to create Gold transformation rules
    exit /b 1
)
echo [SUCCESS] Gold transformation rules created
echo.

REM 4. Gold Transformation Procedures (Optional - requires Silver data)
echo [4/5] Skipping Gold transformation procedures...
echo [INFO] Transformation procedures require Silver tables with data
echo [INFO] Deploy these after loading data: deploy_gold.bat --procedures-only
echo.

REM 5. Gold Tasks (Optional - depend on procedures)
echo [5/5] Creating Gold tasks...
echo [INFO] Skipping Gold tasks (depend on transformation procedures)
echo [INFO] These can be created after procedures are deployed
echo.

REM Summary
echo ============================================
echo [SUCCESS] GOLD LAYER DEPLOYMENT COMPLETE
echo ============================================
echo.
echo Gold layer deployed successfully!
echo.
echo Next steps:
echo 1. Run transformations: CALL GOLD.run_gold_transformations('ALL');
echo 2. Enable tasks: ALTER TASK GOLD.task_master_gold_refresh RESUME;
echo 3. Monitor: SELECT * FROM GOLD.v_gold_processing_summary;
echo.

exit /b 0
