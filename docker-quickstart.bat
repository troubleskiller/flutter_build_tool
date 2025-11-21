@echo off
chcp 65001 >nul 2>&1
:: Docker Quick Start Script - Auto install and start all services
:: The simplest one-click start method

echo ====================================================
echo  Flutter Unity Build Tool - Docker Quick Start
echo ====================================================
echo.

:: Check Docker
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please install Docker Desktop first
    echo.
    echo Opening Docker Desktop download page...
    start https://www.docker.com/products/docker-desktop/
    echo.
    echo After installing Docker Desktop, please run this script again
    pause
    exit /b 1
)

:: Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Starting Docker Desktop, please wait...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo.
    echo Waiting for Docker to fully start (about 30 seconds)...
    timeout /t 30 /nobreak >nul

    :: Check again
    docker info >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] Docker is still not running, please start Docker Desktop manually
        pause
        exit /b 1
    )
)

echo [INFO] Docker is ready
echo.

:: Check and create .env file
if not exist .env (
    echo [CONFIG] Creating environment configuration file...
    if exist .env.docker (
        copy .env.docker .env >nul
    ) else (
        (
            echo # Docker Environment Configuration
            echo JWT_SECRET=change-this-in-production-%RANDOM%
            echo.
            echo # Please modify to your Unity and Flutter paths
            echo UNITY_PROJECT_PATH=C:\your\unity\project
            echo FLUTTER_PROJECT_PATH=C:\your\flutter\project
            echo UNITY_EDITOR_PATH=C:\Program Files\Unity\Hub\Editor\2022.3.10f1\Editor\Unity.exe
            echo FLUTTER_SDK_PATH=C:\flutter\bin\flutter.bat
        ) > .env
    )

    echo.
    echo [IMPORTANT] Please configure your Unity and Flutter project paths
    echo.
    notepad .env
    echo.
    set /p READY="After configuration, press Enter to continue..."
)

:: Start installation
echo.
echo [1/4] Pulling required Docker images...
echo       - PostgreSQL 14 Database
echo       - Redis 7 Cache Service
docker-compose pull postgres redis

echo.
echo [2/4] Building application images...
docker-compose build

echo.
echo [3/4] Starting database services...
docker-compose up -d postgres redis

:: Wait for database to be ready
echo       Waiting for database initialization...
timeout /t 10 /nobreak >nul

echo.
echo [4/4] Starting all services...
docker-compose up -d

:: Wait for services to fully start
echo.
echo Waiting for services to start...
timeout /t 5 /nobreak >nul

:: Check service status
echo.
echo ====================================================
echo  Start Successful!
echo ====================================================
echo.
echo System is ready, you can access:
echo.
echo   Frontend:    http://localhost:3000
echo   Backend API: http://localhost:8000
echo   Database:    http://localhost:8080
echo.
echo   Default:     admin / admin123
echo.
echo ====================================================
echo.
echo Tips:
echo - Use docker-start.bat to manage services
echo - Use docker-compose logs -f to view logs
echo - Use docker-compose down to stop services
echo.
echo Opening browser...
timeout /t 2 /nobreak >nul
start http://localhost:3000

pause