@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: Docker Start Script - Auto pull and configure PostgreSQL and Redis

echo ================================================
echo  Flutter Unity Build Tool - Docker Manager
echo ================================================
echo.

:: Check Docker installation
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed!
    echo.
    echo Please install Docker Desktop first:
    echo https://www.docker.com/products/docker-desktop/
    echo.
    pause
    exit /b 1
)

:: Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not running!
    echo Please start Docker Desktop and try again
    pause
    exit /b 1
)

:: Check .env file
if not exist .env (
    echo [INFO] Creating environment configuration file...
    copy .env.docker .env >nul 2>&1
    echo.
    echo [IMPORTANT] Please edit .env file to configure your Unity and Flutter paths
    echo.
    notepad .env
    pause
)

:: Select operation
echo Please select operation:
echo 1. First installation and start
echo 2. Start services
echo 3. Stop services
echo 4. Restart services
echo 5. View logs
echo 6. Clean all data (DANGEROUS)
echo 7. Update and rebuild
echo.
set /p ACTION="Please enter option (1-7): "

if "%ACTION%"=="1" goto install
if "%ACTION%"=="2" goto start
if "%ACTION%"=="3" goto stop
if "%ACTION%"=="4" goto restart
if "%ACTION%"=="5" goto logs
if "%ACTION%"=="6" goto clean
if "%ACTION%"=="7" goto rebuild
goto :eof

:install
echo.
echo [Step 1/5] Pulling Docker images...
docker-compose pull
if %errorlevel% neq 0 (
    echo [ERROR] Failed to pull images
    pause
    exit /b 1
)

echo.
echo [Step 2/5] Building application images...
docker-compose build
if %errorlevel% neq 0 (
    echo [ERROR] Build failed
    pause
    exit /b 1
)

echo.
echo [Step 3/5] Starting PostgreSQL and Redis...
docker-compose up -d postgres redis
timeout /t 10 >nul

echo.
echo [Step 4/5] Initializing database...
docker-compose exec -T backend npx prisma migrate deploy
docker-compose exec -T backend npx prisma db seed

echo.
echo [Step 5/5] Starting all services...
docker-compose up -d

echo.
echo ================================================
echo  Installation Complete!
echo ================================================
echo.
echo Frontend: http://localhost:3000
echo Backend: http://localhost:8000
echo Database Admin: http://localhost:8080
echo.
echo Default account: admin / admin123
echo.
echo Use docker-start.bat to manage services
echo ================================================
pause
goto :eof

:start
echo.
echo [INFO] Starting services...
docker-compose up -d
echo.
echo Services started:
echo - Frontend: http://localhost:3000
echo - Backend: http://localhost:8000
echo - Database Admin: http://localhost:8080
pause
goto :eof

:stop
echo.
echo [INFO] Stopping services...
docker-compose down
echo Services stopped
pause
goto :eof

:restart
echo.
echo [INFO] Restarting services...
docker-compose restart
echo Services restarted
pause
goto :eof

:logs
echo.
echo Select logs to view:
echo 1. All services
echo 2. Backend
echo 3. Frontend
echo 4. PostgreSQL
echo 5. Redis
set /p LOG_CHOICE="Please select (1-5): "

if "%LOG_CHOICE%"=="1" docker-compose logs -f
if "%LOG_CHOICE%"=="2" docker-compose logs -f backend
if "%LOG_CHOICE%"=="3" docker-compose logs -f frontend
if "%LOG_CHOICE%"=="4" docker-compose logs -f postgres
if "%LOG_CHOICE%"=="5" docker-compose logs -f redis
goto :eof

:clean
echo.
echo [WARNING] This will delete all data!
set /p CONFIRM="Confirm deletion? (yes/no): "
if /i "%CONFIRM%"=="yes" (
    docker-compose down -v
    echo All data has been cleaned
) else (
    echo Operation cancelled
)
pause
goto :eof

:rebuild
echo.
echo [INFO] Updating and rebuilding services...
docker-compose down
docker-compose pull
docker-compose build --no-cache
docker-compose up -d
echo Services have been updated and restarted
pause
goto :eof

endlocal