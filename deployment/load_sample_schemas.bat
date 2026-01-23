@echo off
REM ============================================
REM Load Sample Silver Target Schemas
REM ============================================

setlocal enabledelayedexpansion

REM Get script directory
set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fi"

REM Connection name (optional argument)
if "%~1"=="" (
    set "CONNECTION_NAME=default"
) else (
    set "CONNECTION_NAME=%~1"
)

echo [INFO] Loading sample Silver target schemas...

REM Check if sample data script exists
if not exist "%PROJECT_ROOT%\sample_data\quick_start.sh" (
    echo [ERROR] Sample data script not found
    exit /b 1
)

REM Note: This would need to be converted to batch or PowerShell
REM For now, we'll just provide instructions
echo [INFO] Sample schema loading requires bash script execution
echo [INFO] Please use WSL or Git Bash to run:
echo   cd sample_data
echo   ./quick_start.sh
echo.

exit /b 0
