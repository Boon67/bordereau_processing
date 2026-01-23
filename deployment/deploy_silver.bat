@echo off
REM ============================================
REM SILVER LAYER DEPLOYMENT SCRIPT (Using Snow CLI)
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

echo [SILVER] Deploying Silver Layer using connection: %CONNECTION_NAME%

REM Use environment variables from deploy.bat if set
if not "%DEPLOY_DATABASE%"=="" (
    set "DATABASE=%DEPLOY_DATABASE%"
) else (
    for /f "tokens=*" %%i in ('snow connection list --format json ^| jq -r ".[] | select(.connection_name == \"%CONNECTION_NAME%\") | .database // empty" 2^>nul') do set "DATABASE=%%i"
    if "!DATABASE!"=="" set "DATABASE=FILE_PROCESSING_PIPELINE"
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

echo   Database: %DATABASE%
echo   Silver Schema: %SILVER_SCHEMA%

REM Get project root
for %%i in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fi"

REM Execute Silver SQL scripts in order
call :execute_sql "%PROJECT_ROOT%\silver\1_Silver_Schema_Setup.sql"
if errorlevel 1 exit /b 1

call :execute_sql "%PROJECT_ROOT%\silver\2_Silver_Target_Schemas.sql"
if errorlevel 1 exit /b 1

call :execute_sql "%PROJECT_ROOT%\silver\3_Silver_Mapping_Procedures.sql"
if errorlevel 1 exit /b 1

call :execute_sql "%PROJECT_ROOT%\silver\4_Silver_Rules_Engine.sql"
if errorlevel 1 exit /b 1

call :execute_sql "%PROJECT_ROOT%\silver\5_Silver_Transformation_Logic.sql"
if errorlevel 1 exit /b 1

call :execute_sql "%PROJECT_ROOT%\silver\6_Silver_Tasks.sql"
if errorlevel 1 exit /b 1

echo [SUCCESS] Silver layer deployed successfully
exit /b 0

REM ============================================
REM Functions
REM ============================================

:execute_sql
set "sql_file=%~1"
echo Executing: %sql_file%

REM Create temporary file with substitutions
set "temp_sql=%TEMP%\silver_deploy_%RANDOM%.sql"

REM Read file and replace variables
powershell -Command "(Get-Content '%sql_file%') -replace '^SET DATABASE_NAME = ''.*'';', 'SET DATABASE_NAME = ''%DATABASE%'';' -replace '^SET BRONZE_SCHEMA_NAME = ''.*'';', 'SET BRONZE_SCHEMA_NAME = ''%BRONZE_SCHEMA%'';' -replace '^SET SILVER_SCHEMA_NAME = ''.*'';', 'SET SILVER_SCHEMA_NAME = ''%SILVER_SCHEMA%'';' | Set-Content '%temp_sql%'"

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
