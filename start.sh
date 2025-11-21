#!/bin/bash

# Flutter Unity Build Tool 启动脚本

set -e

echo "=========================================="
echo "Flutter Unity Build Tool - Startup Script"
echo "=========================================="

# 检查环境
check_requirements() {
    echo "Checking requirements..."

    # 检查Python
    if ! command -v python3 &> /dev/null; then
        echo "Error: Python 3 is not installed"
        exit 1
    fi

    # 检查Node.js
    if ! command -v node &> /dev/null; then
        echo "Error: Node.js is not installed"
        exit 1
    fi

    # 检查PostgreSQL
    if ! command -v psql &> /dev/null; then
        echo "Warning: PostgreSQL client not found"
    fi

    # 检查Redis
    if ! command -v redis-cli &> /dev/null; then
        echo "Warning: Redis client not found"
    fi

    echo "Requirements check completed"
}

# 设置环境变量
setup_env() {
    echo "Setting up environment..."

    # 复制环境变量文件
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            echo "Created .env file from .env.example"
            echo "Please edit .env file with your configuration"
            exit 0
        fi
    fi

    # 加载环境变量
    export $(cat .env | grep -v '^#' | xargs)
}

# 安装后端依赖
install_backend() {
    echo "Installing backend dependencies..."
    cd backend

    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi

    # 激活虚拟环境
    source venv/bin/activate

    # 安装依赖
    pip install -r requirements.txt

    cd ..
}

# 安装前端依赖
install_frontend() {
    echo "Installing frontend dependencies..."
    cd frontend
    npm install
    cd ..
}

# 初始化数据库
init_database() {
    echo "Initializing database..."
    cd backend
    source venv/bin/activate
    python scripts/init_db.py
    cd ..
}

# 启动后端服务
start_backend() {
    echo "Starting backend server..."
    cd backend
    source venv/bin/activate

    # 启动FastAPI
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
    BACKEND_PID=$!
    echo "Backend started with PID: $BACKEND_PID"

    cd ..
}

# 启动前端服务
start_frontend() {
    echo "Starting frontend server..."
    cd frontend
    npm run dev &
    FRONTEND_PID=$!
    echo "Frontend started with PID: $FRONTEND_PID"
    cd ..
}

# 启动Redis（如果本地有）
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

# 停止所有服务
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

    # 查找并关闭其他相关进程
    pkill -f "uvicorn app.main:app" || true
    pkill -f "npm run dev" || true

    echo "All services stopped"
}

# 处理退出信号
trap stop_all EXIT INT TERM

# 主函数
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
            echo "Run './start.sh' to start the application"
            ;;
        backend)
            setup_env
            start_backend
            wait $BACKEND_PID
            ;;
        frontend)
            setup_env
            start_frontend
            wait $FRONTEND_PID
            ;;
        dev)
            check_requirements
            setup_env
            start_redis
            start_backend
            start_frontend

            echo ""
            echo "=========================================="
            echo "Application started in development mode"
            echo "Frontend: http://localhost:3000"
            echo "Backend API: http://localhost:8000"
            echo "API Docs: http://localhost:8000/docs"
            echo "Press Ctrl+C to stop"
            echo "=========================================="
            echo ""

            # 等待进程
            wait
            ;;
        *)
            echo "Usage: $0 {install|init|backend|frontend|dev}"
            echo ""
            echo "Commands:"
            echo "  install  - Install all dependencies"
            echo "  init     - Initialize database"
            echo "  backend  - Start backend server only"
            echo "  frontend - Start frontend server only"
            echo "  dev      - Start all services in development mode"
            ;;
    esac
}

# 运行主函数
main "$@"