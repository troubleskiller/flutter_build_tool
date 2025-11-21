@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo Flutter Unity Build Tool - Windows Startup
echo ==========================================

if "%1"=="" goto usage

:: Check requirements
if "%1"=="install" goto install
if "%1"=="init" goto init
if "%1"=="dev" goto dev
if "%1"=="backend" goto backend
if "%1"=="frontend" goto frontend
if "%1"=="build" goto build
if "%1"=="production" goto production
if "%1"=="migrate" goto migrate
if "%1"=="seed" goto seed
goto usage

:check_requirements
echo Checking requirements...

:: Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Node.js is not installed
    echo Please download and install from https://nodejs.org/
    exit /b 1
)

:: Check npm
where npm >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: npm is not installed
    exit /b 1
)

:: Check PostgreSQL (optional)
where psql >nul 2>&1
if %errorlevel% neq 0 (
    echo Warning: PostgreSQL client not found
    echo Please ensure PostgreSQL is installed
)

:: Check Redis (optional)
where redis-cli >nul 2>&1
if %errorlevel% neq 0 (
    echo Warning: Redis client not found
    echo Please ensure Redis is installed or use WSL
)

echo Requirements check completed
goto :eof

:setup_env
:: Copy environment file if not exists
if not exist .env (
    if exist .env.example (
        copy .env.example .env
        echo Created .env file from .env.example
        echo Please edit .env file with your configuration
        pause
        exit /b 0
    )
)

:: Load environment variables from .env file
for /f "tokens=1,2 delims==" %%a in (.env) do (
    if not "%%a"=="" if not "%%b"=="" (
        set "%%a=%%b"
    )
)
goto :eof

:install
call :check_requirements
call :setup_env

echo Installing backend dependencies...
cd backend
call npm install
cd ..

echo Installing frontend dependencies...
cd frontend
call npm install
cd ..

echo.
echo Installation completed!
echo Run "start.bat init" to initialize the database
pause
goto end

:init
call :setup_env

echo Initializing database...
cd backend

echo Generating Prisma client...
call npx prisma generate

echo Running migrations...
call npx prisma migrate deploy

echo Seeding database...
call npm run prisma:seed

cd ..

echo.
echo Database initialized!
echo Run "start.bat dev" to start the application
pause
goto end

:build
call :setup_env

echo Building backend...
cd backend
call npm run build
cd ..

echo Building frontend...
cd frontend
call npm run build
cd ..

echo.
echo Build completed!
pause
goto end

:backend
call :setup_env

echo Starting backend server...
cd backend
call npm run dev
cd ..
goto end

:frontend
call :setup_env

echo Starting frontend server...
cd frontend
call npm run dev
cd ..
goto end

:dev
call :check_requirements
call :setup_env

echo Starting development servers...

:: Start Redis if available (Windows Service or WSL)
echo Checking Redis...
sc query Redis >nul 2>&1
if %errorlevel% equ 0 (
    echo Starting Redis service...
    net start Redis >nul 2>&1
) else (
    echo Redis service not found. Please ensure Redis is running.
)

:: Start backend in new window
echo Starting backend server...
start "Backend Server" cmd /k "cd backend && npm run dev"

:: Wait a moment for backend to start
timeout /t 3 /nobreak >nul

:: Start frontend in new window
echo Starting frontend server...
start "Frontend Server" cmd /k "cd frontend && npm run dev"

echo.
echo ==========================================
echo Application started in development mode
echo Frontend: http://localhost:3000
echo Backend API: http://localhost:8000
echo.
echo Close this window to stop all services
echo ==========================================
echo.
pause
goto end

:production
call :check_requirements
call :setup_env

echo Building for production...
call :build

echo Starting production servers...

:: Start backend in new window
echo Starting backend server...
start "Backend Production" cmd /k "cd backend && npm run start"

:: Wait for backend to start
timeout /t 5 /nobreak >nul

:: Start frontend in new window
echo Starting frontend server...
start "Frontend Production" cmd /k "cd frontend && npm run start"

echo.
echo ==========================================
echo Application started in production mode
echo Frontend: http://localhost:3000
echo Backend API: http://localhost:8000
echo ==========================================
echo.
pause
goto end

:migrate
call :setup_env
cd backend
call npx prisma migrate dev
cd ..
echo Migration completed!
pause
goto end

:seed
call :setup_env
cd backend
call npm run prisma:seed
cd ..
echo Database seeded!
pause
goto end

:usage
echo Usage: start.bat [command]
echo.
echo Commands:
echo   install    - Install all dependencies
echo   init       - Initialize database (migrate + seed)
echo   build      - Build for production
echo   backend    - Start backend server only
echo   frontend   - Start frontend server only
echo   dev        - Start all services in development mode
echo   production - Start all services in production mode
echo   migrate    - Run database migrations
echo   seed       - Seed database with initial data
echo.
pause

:end
endlocal