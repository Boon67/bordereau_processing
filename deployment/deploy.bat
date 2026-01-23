@echo off
REM ============================================
REM SNOWFLAKE FILE PROCESSING PIPELINE
REM Master Deployment Script (Using Snow CLI)
REM ============================================
REM Purpose: Deploy both Bronze and Silver layers using Snow CLI
REM Usage: deploy.bat [options] [connection_name] [config_file]
REM   Options:
REM     -v, --verbose    Enable verbose logging (shows all SQL output)
REM     -h, --help       Show this help message
REM   connection_name: Name of the Snowflake CLI connection (default: uses default connection)
REM   config_file: Path to config file (default: default.config, custom.config if exists)
REM ============================================

setlocal enabledelayedexpansion

REM Get script directory and project root
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."

REM Parse options
set "VERBOSE=false"
set "UNDEPLOY=false"
set "CONNECTION_NAME="
set "CONFIG_FILE="

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="-v" (
    set "VERBOSE=true"
    shift
    goto parse_args
)
if /i "%~1"=="--verbose" (
    set "VERBOSE=true"
    shift
    goto parse_args
)
if /i "%~1"=="-h" (
    call :show_help
    exit /b 0
)
if /i "%~1"=="--help" (
    call :show_help
    exit /b 0
)
if /i "%~1"=="-u" (
    set "UNDEPLOY=true"
    shift
    goto parse_args
)
if /i "%~1"=="--undeploy" (
    set "UNDEPLOY=true"
    shift
    goto parse_args
)
if "!CONNECTION_NAME!"=="" (
    set "CONNECTION_NAME=%~1"
    shift
    goto parse_args
)
if "!CONFIG_FILE!"=="" (
    set "CONFIG_FILE=%~1"
    shift
    goto parse_args
)
shift
goto parse_args

:args_done

REM Export verbose flag for child scripts
set "DEPLOY_VERBOSE=%VERBOSE%"

REM Load configuration files
if exist "%SCRIPT_DIR%default.config" (
    call :load_config "%SCRIPT_DIR%default.config"
)

if exist "%SCRIPT_DIR%custom.config" (
    call :load_config "%SCRIPT_DIR%custom.config"
)

if not "%CONFIG_FILE%"=="" (
    if exist "%CONFIG_FILE%" (
        call :load_config "%CONFIG_FILE%"
    ) else (
        echo [ERROR] Config file not found: %CONFIG_FILE%
        exit /b 1
    )
)

REM Create logs directory
if not exist "%PROJECT_ROOT%\logs" mkdir "%PROJECT_ROOT%\logs"

REM Log file
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set "LOG_DATE=%%c%%a%%b")
for /f "tokens=1-2 delims=/: " %%a in ('time /t') do (set "LOG_TIME=%%a%%b")
set "LOG_FILE=%PROJECT_ROOT%\logs\deployment_%LOG_DATE%_%LOG_TIME%.log"

REM Start deployment
call :print_header

REM Handle undeploy mode
if "%UNDEPLOY%"=="true" (
    call :undeploy_mode
    exit /b !ERRORLEVEL!
)

REM Check Snow CLI
call :log_message INFO "Checking Snowflake CLI configuration..."
call "%SCRIPT_DIR%check_snow_connection.bat"
if errorlevel 1 (
    call :log_message ERROR "Failed to setup Snowflake connection"
    exit /b 1
)

REM Get connection details
if "%CONNECTION_NAME%"=="" (
    if "%USE_DEFAULT_CONNECTION%"=="true" (
        for /f "tokens=*" %%i in ('snow connection list --format json ^| jq -r ".[] | select(.is_default == true) | .connection_name // empty" 2^>nul') do set "CONNECTION_NAME=%%i"
        if "!CONNECTION_NAME!"=="" set "CONNECTION_NAME=default"
        call :log_message INFO "Using default connection: !CONNECTION_NAME!"
    ) else if not "%SNOWFLAKE_CONNECTION%"=="" (
        set "CONNECTION_NAME=%SNOWFLAKE_CONNECTION%"
        call :log_message INFO "Using connection from config: !CONNECTION_NAME!"
    ) else (
        call :select_connection
    )
) else (
    call :log_message INFO "Using connection: %CONNECTION_NAME%"
)

REM Get account from connection
for /f "tokens=*" %%i in ('snow connection list --format json ^| jq -r ".[] | select(.connection_name == \"%CONNECTION_NAME%\") | .account // empty" 2^>nul') do set "ACCOUNT=%%i"

REM Use config values or defaults
if "%DATABASE_NAME%"=="" set "DATABASE_NAME=FILE_PROCESSING_PIPELINE"
if "%SNOWFLAKE_WAREHOUSE%"=="" set "SNOWFLAKE_WAREHOUSE=COMPUTE_WH"
if "%SNOWFLAKE_ROLE%"=="" set "SNOWFLAKE_ROLE=SYSADMIN"
if "%BRONZE_SCHEMA_NAME%"=="" set "BRONZE_SCHEMA_NAME=BRONZE"
if "%SILVER_SCHEMA_NAME%"=="" set "SILVER_SCHEMA_NAME=SILVER"
if "%BRONZE_DISCOVERY_SCHEDULE%"=="" set "BRONZE_DISCOVERY_SCHEDULE=60 MINUTE"

set "DATABASE=%DATABASE_NAME%"
set "WAREHOUSE=%SNOWFLAKE_WAREHOUSE%"
set "ROLE=%SNOWFLAKE_ROLE%"
set "BRONZE_SCHEMA=%BRONZE_SCHEMA_NAME%"
set "SILVER_SCHEMA=%SILVER_SCHEMA_NAME%"
set "DISCOVERY_SCHEDULE=%BRONZE_DISCOVERY_SCHEDULE%"

REM Export for child scripts
set "DEPLOY_DATABASE=%DATABASE%"
set "DEPLOY_WAREHOUSE=%WAREHOUSE%"
set "DEPLOY_BRONZE_SCHEMA=%BRONZE_SCHEMA%"
set "DEPLOY_SILVER_SCHEMA=%SILVER_SCHEMA%"
set "DEPLOY_DISCOVERY_SCHEDULE=%DISCOVERY_SCHEDULE%"

call :log_message INFO "Account: %ACCOUNT%"
call :log_message INFO "Database: %DATABASE%"
call :log_message INFO "Warehouse: %WAREHOUSE%"
call :log_message INFO "Role: %ROLE%"
call :log_message INFO "Bronze Schema: %BRONZE_SCHEMA%"
call :log_message INFO "Silver Schema: %SILVER_SCHEMA%"
call :log_message INFO "Log file: %LOG_FILE%"

REM Display deployment configuration
call :display_config

REM Confirm deployment
if not "%AUTO_APPROVE%"=="true" (
    set /p "CONFIRM=Continue with deployment? (y/n): "
    if /i not "!CONFIRM!"=="y" (
        call :log_message INFO "Deployment cancelled by user"
        exit /b 0
    )
)

REM Check required roles
call :log_message INFO "Checking required roles: SYSADMIN, SECURITYADMIN"
call :check_role SYSADMIN "%CONNECTION_NAME%"
if errorlevel 1 exit /b 1
call :check_role SECURITYADMIN "%CONNECTION_NAME%"
if errorlevel 1 exit /b 1

REM Verify warehouse
snow sql --connection "%CONNECTION_NAME%" -q "SHOW WAREHOUSES LIKE '%WAREHOUSE%';" >nul 2>&1
if errorlevel 1 (
    call :log_message ERROR "Warehouse does not exist or is not accessible: %WAREHOUSE%"
    exit /b 1
)

REM Check EXECUTE TASK privilege
call :check_execute_task

REM Deploy Bronze Layer
echo.
echo [BRONZE] Deploying Bronze Layer...
call "%SCRIPT_DIR%deploy_bronze.bat" "%CONNECTION_NAME%"
if errorlevel 1 (
    call :log_message ERROR "Bronze layer deployment failed"
    exit /b 1
)
call :log_message SUCCESS "Bronze layer deployed successfully"

REM Deploy Silver Layer
echo.
echo [SILVER] Deploying Silver Layer...
call "%SCRIPT_DIR%deploy_silver.bat" "%CONNECTION_NAME%"
if errorlevel 1 (
    call :log_message ERROR "Silver layer deployment failed"
    exit /b 1
)
call :log_message SUCCESS "Silver layer deployed successfully"

REM Load Sample Schemas (Optional)
if not "%AUTO_APPROVE%"=="true" (
    echo.
    echo ============================================================
    echo OPTIONAL: LOAD SAMPLE SILVER TARGET SCHEMAS
    echo ============================================================
    echo.
    echo Would you like to load sample Silver target schemas?
    echo This will:
    echo   - Generate schema definitions for 5 TPAs
    echo   - Create 4 table types (Medical, Dental, Pharmacy, Eligibility)
    echo   - Load 310 column definitions
    echo.
    set /p "LOAD_SCHEMAS=Load sample schemas? (y/n) [y]: "
    if "!LOAD_SCHEMAS!"=="" set "LOAD_SCHEMAS=y"
) else (
    set "LOAD_SCHEMAS=y"
)

set "SCHEMAS_LOADED=false"
if /i "!LOAD_SCHEMAS!"=="y" (
    echo.
    echo [SCHEMAS] Loading sample Silver target schemas...
    call "%SCRIPT_DIR%load_sample_schemas.bat" "%CONNECTION_NAME%"
    if not errorlevel 1 (
        call :log_message SUCCESS "Sample schemas loaded successfully"
        set "SCHEMAS_LOADED=true"
    ) else (
        call :log_message WARNING "Sample schema loading failed or was skipped"
    )
) else (
    call :log_message INFO "Skipping sample schema loading"
)

REM Deploy Gold Layer
echo.
echo [GOLD] Deploying Gold Layer...
call "%SCRIPT_DIR%deploy_gold.bat" "%CONNECTION_NAME%"
if errorlevel 1 (
    call :log_message ERROR "Gold layer deployment failed"
    exit /b 1
)
call :log_message SUCCESS "Gold layer deployed successfully"

REM Optional: Deploy to Snowpark Container Services
if not "%AUTO_APPROVE%"=="true" (
    echo.
    echo ============================================================
    echo OPTIONAL: SNOWPARK CONTAINER SERVICES DEPLOYMENT
    echo ============================================================
    echo.
    echo Would you like to deploy the application to Snowpark Container Services?
    echo This will:
    echo   - Build Docker images for backend and frontend
    echo   - Push images to Snowflake image repository
    echo   - Create compute pool (if needed)
    echo   - Deploy unified service with health checks
    echo.
    set /p "DEPLOY_CONTAINERS=Deploy to Snowpark Container Services? (y/n) [n]: "
    if "!DEPLOY_CONTAINERS!"=="" set "DEPLOY_CONTAINERS=n"
) else (
    set "DEPLOY_CONTAINERS=n"
)

set "CONTAINERS_DEPLOYED=false"
if /i "!DEPLOY_CONTAINERS!"=="y" (
    echo.
    echo [CONTAINERS] Deploying to Snowpark Container Services...
    call "%SCRIPT_DIR%deploy_container.bat"
    if not errorlevel 1 (
        call :log_message SUCCESS "Container deployment completed successfully"
        set "CONTAINERS_DEPLOYED=true"
    ) else (
        call :log_message WARNING "Container deployment failed or was skipped"
    )
) else (
    call :log_message INFO "Skipping Snowpark Container Services deployment"
)

REM Print summary
call :print_summary

call :log_message SUCCESS "Deployment completed successfully"
echo.
echo [SUCCESS] Deployment completed successfully!
echo.

if "%CONTAINERS_DEPLOYED%"=="true" (
    echo Next steps:
    echo 1. Check service status:
    echo    snow spcs service status BORDEREAU_APP --connection %CONNECTION_NAME%
    echo.
    echo 2. Get service endpoint:
    echo    snow spcs service list-endpoints BORDEREAU_APP --connection %CONNECTION_NAME%
    echo.
    echo 3. Upload sample data:
    echo    snow stage put sample_data/claims_data/provider_a/*.csv @BRONZE.SRC/provider_a/ --connection %CONNECTION_NAME%
    echo.
) else (
    echo Next steps:
    echo 1. Start containerized apps locally (React + FastAPI):
    echo    docker-compose up -d
    echo.
    echo    OR deploy to Snowpark Container Services:
    echo    cd deployment ^&^& deploy_container.bat
    echo.
    echo 2. Upload sample data:
    echo    snow stage put sample_data/claims_data/provider_a/*.csv @BRONZE.SRC/provider_a/ --connection %CONNECTION_NAME%
    echo.
)

exit /b 0

REM ============================================
REM Functions
REM ============================================

:show_help
echo ============================================================
echo   SNOWFLAKE FILE PROCESSING PIPELINE DEPLOYMENT SCRIPT
echo ============================================================
echo.
echo USAGE:
echo     deploy.bat [OPTIONS] [CONNECTION_NAME] [CONFIG_FILE]
echo.
echo OPTIONS:
echo     -v, --verbose
echo         Enable verbose logging. Shows all SQL statements and their output
echo         during deployment. Useful for debugging deployment issues.
echo.
echo     -h, --help
echo         Display this help message and exit.
echo.
echo     -u, --undeploy
echo         Undeploy (remove) the database and all associated resources.
echo         WARNING: This will delete all data!
echo.
echo ARGUMENTS:
echo     CONNECTION_NAME
echo         Name of the Snowflake CLI connection to use for deployment.
echo         If not specified, uses the default connection configured in
echo         %%USERPROFILE%%\.snowflake\connections.toml
echo.
echo     CONFIG_FILE
echo         Path to a custom configuration file.
echo.
echo For more information, see: DEPLOYMENT_SNOW_CLI.md
exit /b 0

:load_config
REM Simple config loader - reads KEY=VALUE pairs
for /f "usebackq tokens=1,* delims==" %%a in ("%~1") do (
    set "line=%%a"
    if not "!line:~0,1!"=="#" (
        if not "%%b"=="" (
            set "%%a=%%b"
            set "%%a=!%%a:"=!"
        )
    )
)
exit /b 0

:log_message
set "level=%~1"
shift
set "message=%~1"
echo [%level%] %message%
echo [%date% %time%] [%level%] %message% >> "%LOG_FILE%"
exit /b 0

:print_header
echo.
echo ============================================================
echo      SNOWFLAKE FILE PROCESSING PIPELINE DEPLOYMENT
echo               Using Snowflake CLI (snow)
echo ============================================================
echo.
exit /b 0

:display_config
echo.
echo ============================================================
echo DEPLOYMENT CONFIGURATION
echo ============================================================
echo   Connection:     %CONNECTION_NAME%
echo   Database:       %DATABASE%
echo   Warehouse:      %WAREHOUSE%
echo   Bronze Schema:  %BRONZE_SCHEMA%
echo   Silver Schema:  %SILVER_SCHEMA%
echo.
echo   Objects to be created:
echo     Database:
echo       - %DATABASE%
echo     Schemas:
echo       - %DATABASE%.%BRONZE_SCHEMA%
echo       - %DATABASE%.%SILVER_SCHEMA%
echo     Roles:
echo       - %DATABASE%_ADMIN (full admin access)
echo       - %DATABASE%_READWRITE (read/write + execute procedures)
echo       - %DATABASE%_READONLY (read-only access)
echo ============================================================
echo.
exit /b 0

:check_role
set "role_name=%~1"
set "conn_name=%~2"
snow sql --connection "%conn_name%" -q "USE ROLE %role_name%;" >nul 2>&1
if errorlevel 1 (
    call :log_message ERROR "Missing required role or insufficient privileges: %role_name%"
    exit /b 1
)
exit /b 0

:check_execute_task
call :log_message INFO "Checking EXECUTE TASK privilege for SYSADMIN..."
for /f "tokens=*" %%i in ('snow sql --connection "%CONNECTION_NAME%" --format json -q "SHOW GRANTS TO ROLE SYSADMIN" 2^>nul ^| jq -r ".[] | select(.privilege == \"EXECUTE TASK\" and .granted_on == \"ACCOUNT\") | .privilege" 2^>nul') do set "EXECUTE_TASK_GRANTED=%%i"

if "%EXECUTE_TASK_GRANTED%"=="" (
    call :log_message WARNING "EXECUTE TASK privilege not granted to SYSADMIN"
    call :log_message INFO "Attempting to grant via ACCOUNTADMIN..."
    
    snow sql --connection "%CONNECTION_NAME%" -q "USE ROLE ACCOUNTADMIN; GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;" >nul 2>&1
    if errorlevel 1 (
        call :log_message ERROR "Failed to grant EXECUTE TASK privilege"
        call :log_message ERROR "Please run as ACCOUNTADMIN: GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN WITH GRANT OPTION;"
        exit /b 1
    )
    call :log_message SUCCESS "EXECUTE TASK privilege granted to SYSADMIN"
) else (
    call :log_message SUCCESS "EXECUTE TASK privilege verified for SYSADMIN"
)
exit /b 0

:select_connection
echo.
echo Available Snowflake Connections:
echo.
set "idx=1"
for /f "tokens=*" %%i in ('snow connection list --format json 2^>nul ^| jq -r ".[].connection_name" 2^>nul') do (
    echo   !idx!^) %%i
    set "conn_!idx!=%%i"
    set /a idx+=1
)
set /a max_idx=idx-1
echo.
set /p "selection=Select connection number [1-%max_idx%]: "
set "CONNECTION_NAME=!conn_%selection%!"
call :log_message INFO "Selected connection: !CONNECTION_NAME!"
exit /b 0

:undeploy_mode
call :log_message INFO "UNDEPLOY MODE ACTIVATED"
echo.
echo ============================================================
echo                   WARNING
echo ============================================================
echo   This will DELETE the following:
echo   - Database: %DATABASE_NAME%
echo   - All data in Bronze and Silver layers
echo   - All roles, tasks, and procedures
echo ============================================================
echo.
set /p "confirmation=Are you sure you want to continue? (type 'yes' to confirm): "
if /i not "!confirmation!"=="yes" (
    call :log_message INFO "Undeploy cancelled by user"
    exit /b 0
)

set "DATABASE=%DATABASE_NAME%"
if "%DATABASE%"=="" set "DATABASE=FILE_PROCESSING_PIPELINE"

echo.
set /p "db_confirmation=Type the database name to confirm: "
if not "!db_confirmation!"=="%DATABASE%" (
    call :log_message ERROR "Database name does not match. Undeploy cancelled."
    exit /b 1
)

if "%CONNECTION_NAME%"=="" (
    for /f "tokens=*" %%i in ('snow connection list --format json ^| jq -r ".[] | select(.is_default == true) | .connection_name // empty" 2^>nul') do set "CONNECTION_NAME=%%i"
    if "!CONNECTION_NAME!"=="" set "CONNECTION_NAME=default"
)

call :log_message INFO "Undeploying from connection: %CONNECTION_NAME%"
call :log_message INFO "Dropping database: %DATABASE%"

snow sql --connection "%CONNECTION_NAME%" -q "USE ROLE SYSADMIN; DROP DATABASE IF EXISTS %DATABASE%;" >nul 2>&1
if not errorlevel 1 (
    call :log_message SUCCESS "Database %DATABASE% dropped"
) else (
    call :log_message WARNING "Failed to drop database or database does not exist"
)

call :log_message INFO "Dropping roles..."
snow sql --connection "%CONNECTION_NAME%" -q "USE ROLE SECURITYADMIN; DROP ROLE IF EXISTS %DATABASE%_ADMIN;" >nul 2>&1
snow sql --connection "%CONNECTION_NAME%" -q "USE ROLE SECURITYADMIN; DROP ROLE IF EXISTS %DATABASE%_READWRITE;" >nul 2>&1
snow sql --connection "%CONNECTION_NAME%" -q "USE ROLE SECURITYADMIN; DROP ROLE IF EXISTS %DATABASE%_READONLY;" >nul 2>&1

echo.
call :log_message SUCCESS "Undeploy completed successfully"
echo Database and all associated resources have been removed.
exit /b 0

:print_summary
echo.
echo ============================================================
echo                   DEPLOYMENT SUMMARY
echo ============================================================
echo   Connection: %CONNECTION_NAME%
echo   Database: %DATABASE%
echo   Bronze Schema: %BRONZE_SCHEMA%
echo   Silver Schema: %SILVER_SCHEMA%
echo   Gold Schema: GOLD
echo   Bronze Layer: [OK] Deployed
echo   Silver Layer: [OK] Deployed
if "%SCHEMAS_LOADED%"=="true" (
    echo   Sample Schemas: [OK] Loaded (310 definitions)
) else (
    echo   Sample Schemas: [SKIP] Not loaded
)
echo   Gold Layer: [OK] Deployed
if "%CONTAINERS_DEPLOYED%"=="true" (
    echo   Containers: [OK] Deployed to SPCS
) else (
    echo   Containers: [SKIP] Not deployed
)
echo   Log: %LOG_FILE%
echo ============================================================
exit /b 0
