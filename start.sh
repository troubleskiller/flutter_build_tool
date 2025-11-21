#!/bin/bash

# Flutter Unity Build Tool - Startup Script

set -e

echo "=========================================="
echo "Flutter Unity Build Tool - Startup Script"
echo "=========================================="

# Check requirements
check_requirements() {
    echo "Checking requirements..."

    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo "Error: Node.js is not installed"
        exit 1
    fi

    # Check npm
    if ! command -v npm &> /dev/null; then
        echo "Error: npm is not installed"
        exit 1
    fi

    # Check PostgreSQL
    if ! command -v psql &> /dev/null; then
        echo "Warning: PostgreSQL client not found"
    fi

    # Check Redis
    if ! command -v redis-cli &> /dev/null; then
        echo "Warning: Redis client not found"
    fi

    echo "Requirements check completed"
}

# Setup environment variables
setup_env() {
    echo "Setting up environment..."

    # Copy environment variables file
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            echo "Created .env file from .env.example"
            echo "Please edit .env file with your configuration"
            exit 0
        fi
    fi

    # Load environment variables
    export $(cat .env | grep -v '^#' | xargs)
}

# Install backend dependencies
install_backend() {
    echo "Installing backend dependencies..."
    cd backend
    npm install
    cd ..
}

# Install frontend dependencies
install_frontend() {
    echo "Installing frontend dependencies..."
    cd frontend
    npm install
    cd ..
}

# Initialize database
init_database() {
    echo "Initializing database..."
    cd backend

    # Generate Prisma client
    npx prisma generate

    # Run migrations
    npx prisma migrate deploy

    # Seed database
    npm run prisma:seed

    cd ..
}

# Build backend
build_backend() {
    echo "Building backend..."
    cd backend
    npm run build
    cd ..
}

# Start backend service
start_backend() {
    echo "Starting backend server..."
    cd backend

    if [ "$1" = "production" ]; then
        npm run start &
    else
        npm run dev &
    fi

    BACKEND_PID=$!
    echo "Backend started with PID: $BACKEND_PID"

    cd ..
}

# Start frontend service
start_frontend() {
    echo "Starting frontend server..."
    cd frontend

    if [ "$1" = "production" ]; then
        npm run build
        npm run start &
    else
        npm run dev &
    fi

    FRONTEND_PID=$!
    echo "Frontend started with PID: $FRONTEND_PID"

    cd ..
}

# Start Redis
start_redis() {
    if command -v redis-server &> /dev/null; then
        echo "Starting Redis server..."
        redis-server &
        REDIS_PID=$!
        echo "Redis started with PID: $REDIS_PID"
    else
        echo "Redis not found, assuming external Redis server"
    fi
}

# Stop all services
stop_all() {
    echo "Stopping all services..."

    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null || true
    fi

    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null || true
    fi

    if [ ! -z "$REDIS_PID" ]; then
        kill $REDIS_PID 2>/dev/null || true
    fi

    # Find and kill other related processes
    pkill -f "node.*backend" || true
    pkill -f "next dev" || true

    echo "All services stopped"
}

# Handle exit signals
trap stop_all EXIT INT TERM

# Main function
main() {
    case "${1:-}" in
        install)
            check_requirements
            setup_env
            install_backend
            install_frontend
            echo "Installation completed!"
            echo "Run './start.sh init' to initialize the database"
            ;;
        init)
            setup_env
            init_database
            echo "Database initialized!"
            echo "Run './start.sh dev' to start the application"
            ;;
        build)
            setup_env
            build_backend
            cd frontend
            npm run build
            cd ..
            echo "Build completed!"
            ;;
        backend)
            setup_env
            start_backend development
            wait $BACKEND_PID
            ;;
        frontend)
            setup_env
            start_frontend development
            wait $FRONTEND_PID
            ;;
        dev)
            check_requirements
            setup_env
            start_redis
            start_backend development
            start_frontend development

            echo ""
            echo "=========================================="
            echo "Application started in development mode"
            echo "Frontend: http://localhost:3000"
            echo "Backend API: http://localhost:8000"
            echo "Press Ctrl+C to stop"
            echo "=========================================="
            echo ""

            # Wait for processes
            wait
            ;;
        production)
            check_requirements
            setup_env
            start_redis
            start_backend production
            start_frontend production

            echo ""
            echo "=========================================="
            echo "Application started in production mode"
            echo "Frontend: http://localhost:3000"
            echo "Backend API: http://localhost:8000"
            echo "Press Ctrl+C to stop"
            echo "=========================================="
            echo ""

            # Wait for processes
            wait
            ;;
        migrate)
            setup_env
            cd backend
            npx prisma migrate dev
            cd ..
            echo "Migration completed!"
            ;;
        seed)
            setup_env
            cd backend
            npm run prisma:seed
            cd ..
            echo "Database seeded!"
            ;;
        *)
            echo "Usage: $0 {install|init|build|backend|frontend|dev|production|migrate|seed}"
            echo ""
            echo "Commands:"
            echo "  install    - Install all dependencies"
            echo "  init       - Initialize database (migrate + seed)"
            echo "  build      - Build for production"
            echo "  backend    - Start backend server only"
            echo "  frontend   - Start frontend server only"
            echo "  dev        - Start all services in development mode"
            echo "  production - Start all services in production mode"
            echo "  migrate    - Run database migrations"
            echo "  seed       - Seed database with initial data"
            ;;
    esac
}

# Run main function
main "$@"