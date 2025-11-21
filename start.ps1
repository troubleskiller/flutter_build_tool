# Flutter Unity Build Tool - PowerShell Script
# Run with: powershell -ExecutionPolicy Bypass -File start.ps1 [command]

param(
    [Parameter(Position=0)]
    [string]$Command = "usage"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Flutter Unity Build Tool - Windows Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check requirements
function Test-Requirements {
    Write-Host "Checking requirements..." -ForegroundColor Yellow

    # Check Node.js
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Node.js is not installed" -ForegroundColor Red
        Write-Host "Please download and install from https://nodejs.org/" -ForegroundColor Yellow
        exit 1
    }

    # Check npm
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "Error: npm is not installed" -ForegroundColor Red
        exit 1
    }

    # Check PostgreSQL (optional)
    if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
        Write-Host "Warning: PostgreSQL client not found" -ForegroundColor Yellow
        Write-Host "Please ensure PostgreSQL is installed and added to PATH" -ForegroundColor Yellow
    }

    # Check Redis (optional)
    if (-not (Get-Command redis-cli -ErrorAction SilentlyContinue)) {
        Write-Host "Warning: Redis client not found" -ForegroundColor Yellow
        Write-Host "Consider using Redis for Windows or WSL" -ForegroundColor Yellow
    }

    Write-Host "Requirements check completed" -ForegroundColor Green
}

# Function to setup environment variables
function Set-EnvironmentVariables {
    # Check if .env exists
    if (-not (Test-Path .env)) {
        if (Test-Path .env.example) {
            Copy-Item .env.example .env
            Write-Host "Created .env file from .env.example" -ForegroundColor Green
            Write-Host "Please edit .env file with your configuration" -ForegroundColor Yellow
            Read-Host "Press Enter to continue..."
            exit
        }
    }

    # Load environment variables from .env
    Get-Content .env | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.+)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

# Function to start Redis
function Start-RedisServer {
    # Check if Redis is running as Windows service
    $redisService = Get-Service -Name "Redis" -ErrorAction SilentlyContinue
    if ($redisService) {
        if ($redisService.Status -ne "Running") {
            Write-Host "Starting Redis service..." -ForegroundColor Yellow
            Start-Service -Name "Redis"
        } else {
            Write-Host "Redis service is already running" -ForegroundColor Green
        }
    } else {
        # Check if redis-server is available
        if (Get-Command redis-server -ErrorAction SilentlyContinue) {
            Write-Host "Starting Redis server..." -ForegroundColor Yellow
            Start-Process redis-server -WindowStyle Hidden
        } else {
            Write-Host "Redis not found. Please ensure Redis is installed or running" -ForegroundColor Yellow
        }
    }
}

# Function to stop all processes
function Stop-AllProcesses {
    Write-Host "Stopping all processes..." -ForegroundColor Yellow

    # Stop Node.js processes
    Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force

    # Stop Redis if running as process (not service)
    Get-Process redis-server -ErrorAction SilentlyContinue | Stop-Process -Force

    Write-Host "All processes stopped" -ForegroundColor Green
}

# Main script logic
switch ($Command) {
    "install" {
        Test-Requirements
        Set-EnvironmentVariables

        Write-Host "Installing backend dependencies..." -ForegroundColor Yellow
        Set-Location backend
        npm install
        Set-Location ..

        Write-Host "Installing frontend dependencies..." -ForegroundColor Yellow
        Set-Location frontend
        npm install
        Set-Location ..

        Write-Host ""
        Write-Host "Installation completed!" -ForegroundColor Green
        Write-Host "Run './start.ps1 init' to initialize the database" -ForegroundColor Cyan
    }

    "init" {
        Set-EnvironmentVariables

        Write-Host "Initializing database..." -ForegroundColor Yellow
        Set-Location backend

        Write-Host "Generating Prisma client..." -ForegroundColor Yellow
        npx prisma generate

        Write-Host "Running migrations..." -ForegroundColor Yellow
        npx prisma migrate deploy

        Write-Host "Seeding database..." -ForegroundColor Yellow
        npm run prisma:seed

        Set-Location ..

        Write-Host ""
        Write-Host "Database initialized!" -ForegroundColor Green
        Write-Host "Run './start.ps1 dev' to start the application" -ForegroundColor Cyan
    }

    "build" {
        Set-EnvironmentVariables

        Write-Host "Building backend..." -ForegroundColor Yellow
        Set-Location backend
        npm run build
        Set-Location ..

        Write-Host "Building frontend..." -ForegroundColor Yellow
        Set-Location frontend
        npm run build
        Set-Location ..

        Write-Host ""
        Write-Host "Build completed!" -ForegroundColor Green
    }

    "backend" {
        Set-EnvironmentVariables

        Write-Host "Starting backend server..." -ForegroundColor Yellow
        Set-Location backend
        npm run dev
    }

    "frontend" {
        Set-EnvironmentVariables

        Write-Host "Starting frontend server..." -ForegroundColor Yellow
        Set-Location frontend
        npm run dev
    }

    "dev" {
        Test-Requirements
        Set-EnvironmentVariables

        Write-Host "Starting development servers..." -ForegroundColor Yellow

        # Start Redis
        Start-RedisServer

        # Start backend in new window
        Write-Host "Starting backend server..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend; npm run dev" -WorkingDirectory $PSScriptRoot

        # Wait for backend to start
        Start-Sleep -Seconds 3

        # Start frontend in new window
        Write-Host "Starting frontend server..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd frontend; npm run dev" -WorkingDirectory $PSScriptRoot

        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "Application started in development mode" -ForegroundColor Green
        Write-Host "Frontend: http://localhost:3000" -ForegroundColor Green
        Write-Host "Backend API: http://localhost:8000" -ForegroundColor Green
        Write-Host ""
        Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
        Write-Host "==========================================" -ForegroundColor Cyan

        # Keep script running
        Read-Host "Press Enter to stop all services..."
        Stop-AllProcesses
    }

    "production" {
        Test-Requirements
        Set-EnvironmentVariables

        Write-Host "Building for production..." -ForegroundColor Yellow
        & $PSScriptRoot\start.ps1 build

        Write-Host "Starting production servers..." -ForegroundColor Yellow

        # Start Redis
        Start-RedisServer

        # Start backend
        Write-Host "Starting backend server..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend; npm run start" -WorkingDirectory $PSScriptRoot

        # Wait for backend
        Start-Sleep -Seconds 5

        # Start frontend
        Write-Host "Starting frontend server..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd frontend; npm run start" -WorkingDirectory $PSScriptRoot

        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "Application started in production mode" -ForegroundColor Green
        Write-Host "Frontend: http://localhost:3000" -ForegroundColor Green
        Write-Host "Backend API: http://localhost:8000" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Cyan

        Read-Host "Press Enter to stop all services..."
        Stop-AllProcesses
    }

    "migrate" {
        Set-EnvironmentVariables
        Set-Location backend
        npx prisma migrate dev
        Set-Location ..
        Write-Host "Migration completed!" -ForegroundColor Green
    }

    "seed" {
        Set-EnvironmentVariables
        Set-Location backend
        npm run prisma:seed
        Set-Location ..
        Write-Host "Database seeded!" -ForegroundColor Green
    }

    "stop" {
        Stop-AllProcesses
    }

    default {
        Write-Host "Usage: ./start.ps1 [command]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Cyan
        Write-Host "  install    - Install all dependencies" -ForegroundColor White
        Write-Host "  init       - Initialize database (migrate + seed)" -ForegroundColor White
        Write-Host "  build      - Build for production" -ForegroundColor White
        Write-Host "  backend    - Start backend server only" -ForegroundColor White
        Write-Host "  frontend   - Start frontend server only" -ForegroundColor White
        Write-Host "  dev        - Start all services in development mode" -ForegroundColor White
        Write-Host "  production - Start all services in production mode" -ForegroundColor White
        Write-Host "  migrate    - Run database migrations" -ForegroundColor White
        Write-Host "  seed       - Seed database with initial data" -ForegroundColor White
        Write-Host "  stop       - Stop all running services" -ForegroundColor White
        Write-Host ""
    }
}