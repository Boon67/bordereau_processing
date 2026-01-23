@echo off
REM ============================================
REM Undeploy Script - Remove all resources
REM ============================================

setlocal enabledelayedexpansion

REM Get script directory
set "SCRIPT_DIR=%~dp0"

REM Load configuration
if exist "%SCRIPT_DIR%default.config" (
    call :load_config "%SCRIPT_DIR%default.config"
)

if exist "%SCRIPT_DIR%custom.config" (
    call :load_config "%SCRIPT_DIR%custom.config"
)

if "%DATABASE_NAME%"=="" set "DATABASE_NAME=FILE_PROCESSING_PIPELINE"
set "DATABASE=%DATABASE_NAME%"

echo.
echo ============================================================
echo                   WARNING
echo ============================================================
echo   This will DELETE the following:
echo   - Database: %DATABASE%
echo   - All data in Bronze, Silver, and Gold layers
echo   - All roles, tasks, and procedures
echo ============================================================
echo.

set /p "confirmation=Are you sure you want to continue? (type 'yes' to confirm): "
if /i not "%confirmation%"=="yes" (
    echo [INFO] Undeploy cancelled by user
    exit /b 0
)

echo.
set /p "db_confirmation=Type the database name to confirm: "
if not "%db_confirmation%"=="%DATABASE%" (
    echo [ERROR] Database name does not match. Undeploy cancelled.
    exit /b 1
)

REM Get connection
if "%CONNECTION_NAME%"=="" (
    for /f "tokens=*" %%i in ('snow connection list --format json ^| jq -r ".[] | select(.is_default == true) | .connection_name // empty" 2^>nul') do set "CONNECTION_NAME=%%i"
    if "!CONNECTION_NAME!"=="" set "CONNECTION_NAME=default"
)

echo.
echo [INFO] Undeploying from connection: %CONNECTION_NAME%
echo [INFO] Dropping database: %DATABASE%

REM Drop database
snow sql --connection "%CONNECTION_NAME%" -q "USE ROLE SYSADMIN; DROP DATABASE IF EXISTS %DATABASE%;" >nul 2>&1
if not errorlevel 1 (
    echo [SUCCESS] Database %DATABASE% dropped
) else (
    echo [WARNING] Failed to drop database or database does not exist
)

REM Drop roles
echo [INFO] Dropping roles...
snow sql --connection "%CONNECTION_NAME%" -q "USE ROLE SECURITYADMIN; DROP ROLE IF EXISTS %DATABASE%_ADMIN;" >nul 2>&1
snow sql --connection "%CONNECTION_NAME%" -q "USE ROLE SECURITYADMIN; DROP ROLE IF EXISTS %DATABASE%_READWRITE;" >nul 2>&1
snow sql --connection "%CONNECTION_NAME%" -q "USE ROLE SECURITYADMIN; DROP ROLE IF EXISTS %DATABASE%_READONLY;" >nul 2>&1

echo.
echo [SUCCESS] Undeploy completed successfully
echo Database and all associated resources have been removed.

exit /b 0

REM ============================================
REM Functions
REM ============================================

:load_config
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
