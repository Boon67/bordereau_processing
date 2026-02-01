@echo off
REM ============================================
REM BUILD AND PUSH IMAGES TO GITHUB CONTAINER REGISTRY
REM ============================================
REM Purpose: Build Docker images and push to ghcr.io (Windows)
REM Usage: build_and_push_ghcr.bat [github_username] [version]
REM ============================================

setlocal enabledelayedexpansion

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║     BUILD AND PUSH TO GITHUB CONTAINER REGISTRY           ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

REM Get parameters
set GITHUB_USERNAME=%1
set VERSION=%2

if "%VERSION%"=="" set VERSION=latest

REM Get GitHub username if not provided
if "%GITHUB_USERNAME%"=="" (
    REM Try to detect from git remote
    for /f "tokens=*" %%i in ('git remote get-url origin 2^>nul') do set GIT_REMOTE=%%i
    if not "!GIT_REMOTE!"=="" (
        for /f "tokens=2 delims=/" %%a in ("!GIT_REMOTE!") do set DETECTED_USERNAME=%%a
        if not "!DETECTED_USERNAME!"=="" (
            echo Detected GitHub username from git: !DETECTED_USERNAME!
            set /p USE_DETECTED="Use this username? (y/n): "
            if /i "!USE_DETECTED!"=="y" (
                set GITHUB_USERNAME=!DETECTED_USERNAME!
            )
        )
    )
    
    if "!GITHUB_USERNAME!"=="" (
        set /p GITHUB_USERNAME="GitHub username (for ghcr.io/USERNAME/bordereau): "
    )
)

if "%GITHUB_USERNAME%"=="" (
    echo [ERROR] GitHub username is required
    exit /b 1
)

echo Configuration:
echo   GitHub User:    %GITHUB_USERNAME%
echo   Version:        %VERSION%
echo.

REM Set image names
set REPO_PREFIX=ghcr.io/%GITHUB_USERNAME%/bordereau
set FRONTEND_IMAGE=%REPO_PREFIX%/frontend:%VERSION%
set BACKEND_IMAGE=%REPO_PREFIX%/backend:%VERSION%

echo   Frontend Image: %FRONTEND_IMAGE%
echo   Backend Image:  %BACKEND_IMAGE%
echo.

REM Check if Docker is running
docker info >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Docker is not running
    echo Please start Docker Desktop and try again
    exit /b 1
)

echo [OK] Docker is running
echo.

REM Check GHCR authentication
echo Checking GHCR authentication...
echo.
echo To log in to GitHub Container Registry:
echo   1. Create a Personal Access Token at:
echo      https://github.com/settings/tokens
echo   2. Grant 'write:packages' and 'read:packages' scopes
echo   3. Run: echo YOUR_TOKEN ^| docker login ghcr.io -u %GITHUB_USERNAME% --password-stdin
echo.
set /p CONTINUE="Press Enter once you're logged in, or Ctrl+C to exit..."
echo.

REM Build frontend
echo [1/4] Building frontend image...
docker build -f docker/Dockerfile.frontend -t %FRONTEND_IMAGE% --build-arg APP_NAME="Bordereau Pipeline" --build-arg API_URL="/api" .

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to build frontend image
    exit /b 1
)

echo [OK] Frontend image built
echo.

REM Build backend
echo [2/4] Building backend image...
docker build -f docker/Dockerfile.backend -t %BACKEND_IMAGE% --build-arg ALLOWED_LLM_MODELS="CLAUDE-4-SONNET,OPENAI-GPT-4.1" .

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to build backend image
    exit /b 1
)

echo [OK] Backend image built
echo.

REM Push frontend
echo [3/4] Pushing frontend image to GHCR...
docker push %FRONTEND_IMAGE%

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to push frontend image
    echo Make sure you're logged in: docker login ghcr.io
    exit /b 1
)

echo [OK] Frontend image pushed
echo.

REM Push backend
echo [4/4] Pushing backend image to GHCR...
docker push %BACKEND_IMAGE%

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to push backend image
    exit /b 1
)

echo [OK] Backend image pushed
echo.

REM Also tag as latest if version is not "latest"
if not "%VERSION%"=="latest" (
    echo Tagging as latest...
    
    docker tag %FRONTEND_IMAGE% %REPO_PREFIX%/frontend:latest
    docker tag %BACKEND_IMAGE% %REPO_PREFIX%/backend:latest
    
    docker push %REPO_PREFIX%/frontend:latest
    docker push %REPO_PREFIX%/backend:latest
    
    echo [OK] Also tagged and pushed as 'latest'
    echo.
)

REM Summary
echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║              BUILD AND PUSH COMPLETE                      ║
echo ╠═══════════════════════════════════════════════════════════╣
echo ║  Images pushed to GitHub Container Registry:             ║
echo ║                                                           ║
echo ║  Frontend: %FRONTEND_IMAGE%
echo ║  Backend:  %BACKEND_IMAGE%
echo ╚═══════════════════════════════════════════════════════════╝
echo.

echo [SUCCESS] Build and push completed!
echo.
echo Next steps:
echo   1. Make images public (optional):
echo      - Go to https://github.com/%GITHUB_USERNAME%?tab=packages
echo      - Click on each package
echo      - Go to Package settings - Change visibility - Public
echo.
echo   2. Deploy to Snowflake:
echo      deployment\deploy_container_ghcr.bat [connection_name] %GITHUB_USERNAME% %VERSION%
echo.
echo   3. View images:
echo      https://github.com/%GITHUB_USERNAME%?tab=packages
echo.

endlocal
