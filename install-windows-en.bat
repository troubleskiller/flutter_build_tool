@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: Flutter Unity Build Tool - Windows One-Click Installation Script
:: Automatically installs all dependencies

echo ============================================
echo Flutter Unity Build Tool - Windows Installer
echo ============================================
echo.

:: Check administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please run this script as Administrator
    echo Right-click on this file and select "Run as administrator"
    pause
    exit /b 1
)

:: Select installation mode
echo Please select installation mode:
echo 1. Docker mode (Recommended, simplest)
echo 2. Local installation mode (requires PostgreSQL and Redis)
echo 3. Lightweight mode (uses SQLite, no database required)
echo.
set /p MODE="Please enter option (1/2/3): "

if "%MODE%"=="1" goto docker_mode
if "%MODE%"=="2" goto local_mode
if "%MODE%"=="3" goto lite_mode
goto :eof

:: ==================== Docker Mode ====================
:docker_mode
echo.
echo [Docker Mode] Starting installation...
echo.

:: Check Docker
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Docker is not installed, downloading Docker Desktop...
    echo.
    echo Please visit the following URL to download and install Docker Desktop:
    echo https://www.docker.com/products/docker-desktop/
    echo.
    echo After installation, please run this script again
    start https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)

echo [INFO] Docker is installed
echo.
echo [SUCCESS] Docker mode configuration complete!
echo.
echo Usage:
echo 1. Run: docker-compose up -d
echo 2. Access: http://localhost:3000
echo 3. Default account: admin/admin123
echo.
echo Or use: docker-quickstart.bat for one-click start
echo.
pause
goto :eof

:: ==================== Local Mode ====================
:local_mode
echo.
echo [Local Mode] Starting dependency installation...
echo.

:: Check and install Chocolatey (Windows package manager)
where choco >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Installing Chocolatey package manager...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    set "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
)

:: Check and install Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Installing Node.js...
    choco install nodejs -y
    refreshenv
)

:: Check and install PostgreSQL
where psql >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Installing PostgreSQL...
    choco install postgresql14 -y --params '/Password:postgres'
    refreshenv

    :: Create database
    echo [INFO] Creating database...
    set PGPASSWORD=postgres
    "C:\Program Files\PostgreSQL\14\bin\psql.exe" -U postgres -c "CREATE DATABASE flutter_unity_build;"
)

:: Install Redis (using Memurai - Windows Redis)
where redis-cli >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Installing Redis (Memurai)...
    echo.
    echo Please visit the following URL to download and install Memurai:
    echo https://www.memurai.com/get-memurai
    echo.
    echo Or use WSL to install Redis:
    echo wsl --install
    echo wsl sudo apt update
    echo wsl sudo apt install redis-server
    echo.
    start https://www.memurai.com/get-memurai
)

:: Check Git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Installing Git...
    choco install git -y
    refreshenv
)

:: Install project dependencies
echo [INFO] Installing project dependencies...
call npm install -g pnpm
cd backend
call pnpm install
cd ..\frontend
call pnpm install
cd ..

:: Create environment file
echo [INFO] Creating configuration file...
copy .env.windows.example .env

echo.
echo [SUCCESS] Local mode installation complete!
echo.
echo Next steps:
echo 1. Edit .env file to configure Unity and Flutter paths
echo 2. Run: start.bat init (initialize database)
echo 3. Run: start.bat dev (start development server)
echo.
pause
goto :eof

:: ==================== Lightweight Mode (SQLite) ====================
:lite_mode
echo.
echo [Lightweight Mode] Configuring SQLite version...
echo.

:: Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Downloading Node.js installer...
    echo Please visit https://nodejs.org/ to download and install Node.js
    start https://nodejs.org/
    echo.
    echo After installation, please run this script again
    pause
    exit /b 1
)

:: Create SQLite configuration
echo [INFO] Creating SQLite configuration...
call :create_sqlite_config

:: Install dependencies
echo [INFO] Installing project dependencies...
cd backend
call npm install
call npm install sqlite3
cd ..\frontend
call npm install
cd ..

echo.
echo [SUCCESS] Lightweight mode configuration complete!
echo.
echo Usage:
echo 1. Run: start-lite.bat dev
echo 2. Access: http://localhost:3000
echo 3. Default account: admin/admin123
echo.
echo Note: Lightweight mode uses SQLite database and memory cache, suitable for development/testing only
echo.
pause
goto :eof

:: ==================== Helper Functions ====================

:create_sqlite_config
:: Create SQLite version environment file
(
echo # SQLite Lightweight Configuration
echo NODE_ENV=development
echo PORT=8000
echo.
echo # Security
echo JWT_SECRET=dev-secret-key-change-in-production
echo JWT_EXPIRE=7d
echo.
echo # Database - Using SQLite
echo DATABASE_URL=file:./dev.db
echo DATABASE_TYPE=sqlite
echo.
echo # Redis - Using memory cache
echo USE_REDIS=false
echo.
echo # Frontend
echo FRONTEND_URL=http://localhost:3000
echo.
echo # Unity Configuration - Please modify to your paths
echo UNITY_EDITOR_PATH=C:\Program Files\Unity\Hub\Editor\2022.3.10f1\Editor\Unity.exe
echo UNITY_REPO_PATH=C:\unity_project
echo UNITY_REPO_URL=
echo.
echo # Flutter Configuration - Please modify to your paths
echo FLUTTER_SDK_PATH=C:\flutter
echo FLUTTER_REPO_PATH=C:\flutter_project
echo FLUTTER_REPO_URL=
echo.
echo # Build Settings
echo BUILD_TIMEOUT=3600000
echo MAX_CONCURRENT_BUILDS=1
) > .env.lite

:: Create lightweight startup script
(
echo @echo off
echo chcp 65001 ^>nul 2^>^&1
echo.
echo :: Lightweight mode startup script
echo set DATABASE_TYPE=sqlite
echo set USE_REDIS=false
echo.
echo if "%%1"=="dev" ^(
echo     echo Starting lite development mode...
echo     start "Backend" cmd /k "cd backend && npm run dev"
echo     timeout /t 3 ^>nul
echo     start "Frontend" cmd /k "cd frontend && npm run dev"
echo     echo.
echo     echo Application started!
echo     echo Frontend: http://localhost:3000
echo     echo Backend: http://localhost:8000
echo     pause
echo ^) else ^(
echo     echo Usage: start-lite.bat dev
echo ^)
) > start-lite.bat
goto :eof

endlocal