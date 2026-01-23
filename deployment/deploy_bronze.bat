@echo off
REM ============================================
REM BRONZE LAYER DEPLOYMENT SCRIPT (Using Snow CLI)
REM ============================================

setlocal enabledelayedexpansion

REM Get script directory
set "SCRIPT_DIR=%~dp0"

REM Connection name (optional argument)
if "%~1"=="" (
    set "CONNECTION_NAME=default"
) else (
    set "CONNECTION_NAME=%~1"
)

echo [BRONZE] Deploying Bronze Layer using connection: %CONNECTION_NAME%

REM Use environment variables from deploy.bat if set
if not "%DEPLOY_DATABASE%"=="" (
    set "DATABASE=%DEPLOY_DATABASE%"
) else (
    for /f "tokens=*" %%i in ('snow connection list --format json ^| jq -r ".[] | select(.connection_name == \"%CONNECTION_NAME%\") | .database // empty" 2^>nul') do set "DATABASE=%%i"
    if "!DATABASE!"=="" set "DATABASE=FILE_PROCESSING_PIPELINE"
)

if not "%DEPLOY_WAREHOUSE%"=="" (
    set "WAREHOUSE=%DEPLOY_WAREHOUSE%"
) else (
    for /f "tokens=*" %%i in ('snow connection list --format json ^| jq -r ".[] | select(.connection_name == \"%CONNECTION_NAME%\") | .warehouse // empty" 2^>nul') do set "WAREHOUSE=%%i"
    if "!WAREHOUSE!"=="" set "WAREHOUSE=COMPUTE_WH"
)

if not "%DEPLOY_BRONZE_SCHEMA%"=="" (
    set "BRONZE_SCHEMA=%DEPLOY_BRONZE_SCHEMA%"
) else (
    set "BRONZE_SCHEMA=BRONZE"
)

if not "%DEPLOY_SILVER_SCHEMA%"=="" (
    set "SILVER_SCHEMA=%DEPLOY_SILVER_SCHEMA%"
) else (
    set "SILVER_SCHEMA=SILVER"
)

if not "%DEPLOY_DISCOVERY_SCHEDULE%"=="" (
    set "BRONZE_DISCOVERY_SCHEDULE=%DEPLOY_DISCOVERY_SCHEDULE%"
) else (
    set "BRONZE_DISCOVERY_SCHEDULE=60 MINUTE"
)

echo   Database: %DATABASE%
echo   Bronze Schema: %BRONZE_SCHEMA%
echo   Warehouse: %WAREHOUSE%

REM Get project root
for %%i in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fi"

REM Execute Bronze SQL scripts in order
call :execute_sql "%PROJECT_ROOT%\bronze\1_Setup_Database_Roles.sql"
if errorlevel 1 exit /b 1

call :execute_sql "%PROJECT_ROOT%\bronze\2_Bronze_Schema_Tables.sql"
if errorlevel 1 exit /b 1

call :execute_sql "%PROJECT_ROOT%\bronze\3_Bronze_Setup_Logic.sql"
if errorlevel 1 exit /b 1

call :execute_sql "%PROJECT_ROOT%\bronze\4_Bronze_Tasks.sql"
if errorlevel 1 exit /b 1

echo [SUCCESS] Bronze layer deployed successfully
exit /b 0

REM ============================================
REM Functions
REM ============================================

:execute_sql
set "sql_file=%~1"
echo Executing: %sql_file%

REM Create temporary file with substitutions
set "temp_sql=%TEMP%\bronze_deploy_%RANDOM%.sql"

REM Read file and replace variables
powershell -Command "(Get-Content '%sql_file%') -replace '^SET DATABASE_NAME = ''.*'';', 'SET DATABASE_NAME = ''%DATABASE%'';' -replace '^SET BRONZE_SCHEMA_NAME = ''.*'';', 'SET BRONZE_SCHEMA_NAME = ''%BRONZE_SCHEMA%'';' -replace '^SET SILVER_SCHEMA_NAME = ''.*'';', 'SET SILVER_SCHEMA_NAME = ''%SILVER_SCHEMA%'';' -replace '^SET WAREHOUSE_NAME = ''.*'';', 'SET WAREHOUSE_NAME = ''%WAREHOUSE%'';' -replace '^SET SNOWFLAKE_WAREHOUSE = ''.*'';', 'SET SNOWFLAKE_WAREHOUSE = ''%WAREHOUSE%'';' -replace '^SET BRONZE_DISCOVERY_SCHEDULE = ''.*'';', 'SET BRONZE_DISCOVERY_SCHEDULE = ''%BRONZE_DISCOVERY_SCHEDULE%'';' -replace '__BRONZE_DISCOVERY_SCHEDULE__', '%BRONZE_DISCOVERY_SCHEDULE%' | Set-Content '%temp_sql%'"

REM Execute SQL
if "%DEPLOY_VERBOSE%"=="true" (
    snow sql -f "%temp_sql%" --connection "%CONNECTION_NAME%"
    set "result=!ERRORLEVEL!"
) else (
    snow sql -f "%temp_sql%" --connection "%CONNECTION_NAME%" >nul 2>&1
    set "result=!ERRORLEVEL!"
    if !result! neq 0 (
        REM Show error output
        snow sql -f "%temp_sql%" --connection "%CONNECTION_NAME%"
    )
)

REM Cleanup
del "%temp_sql%" 2>nul

exit /b !result!
