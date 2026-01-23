@echo off
REM ============================================
REM Check Snowflake CLI Connection
REM ============================================

setlocal enabledelayedexpansion

REM Check if snow CLI is installed
where snow >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Snowflake CLI (snow) is not installed
    echo.
    echo Please install it from:
    echo https://docs.snowflake.com/en/developer-guide/snowflake-cli/index
    echo.
    echo Installation:
    echo   pip install snowflake-cli-labs
    echo.
    exit /b 1
)

REM Check if jq is installed
where jq >nul 2>&1
if errorlevel 1 (
    echo [WARNING] jq is not installed (optional but recommended)
    echo.
    echo Download from: https://stedolan.github.io/jq/download/
    echo.
)

REM Check if any connections are configured
snow connection list >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No Snowflake connections configured
    echo.
    echo Please configure a connection:
    echo   snow connection add
    echo.
    echo Or manually edit: %%USERPROFILE%%\.snowflake\connections.toml
    echo.
    exit /b 1
)

echo [SUCCESS] Snowflake CLI is configured
exit /b 0
