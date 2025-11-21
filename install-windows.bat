@echo off
setlocal enabledelayedexpansion

:: Flutter Unity Build Tool - Windows 一键安装脚本
:: 自动安装所有依赖

echo ============================================
echo Flutter Unity Build Tool - Windows 一键安装
echo ============================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 请使用管理员权限运行此脚本
    echo 右键点击本文件，选择"以管理员身份运行"
    pause
    exit /b 1
)

:: 选择安装模式
echo 请选择安装模式：
echo 1. Docker模式（推荐，最简单）
echo 2. 本地安装模式（需要安装PostgreSQL和Redis）
echo 3. 轻量级模式（使用SQLite，无需数据库）
echo.
set /p MODE="请输入选项 (1/2/3): "

if "%MODE%"=="1" goto docker_mode
if "%MODE%"=="2" goto local_mode
if "%MODE%"=="3" goto lite_mode
goto :eof

:: ==================== Docker模式 ====================
:docker_mode
echo.
echo [Docker模式] 开始安装...
echo.

:: 检查Docker
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [信息] Docker未安装，正在下载Docker Desktop...
    echo.
    echo 请访问以下网址下载安装Docker Desktop：
    echo https://www.docker.com/products/docker-desktop/
    echo.
    echo 安装完成后，请重新运行此脚本
    start https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)

echo [信息] Docker已安装

:: 创建docker-compose文件
echo [信息] 创建Docker配置文件...
call :create_docker_compose

echo.
echo [成功] Docker模式配置完成！
echo.
echo 使用方法：
echo 1. 运行: docker-compose up -d
echo 2. 访问: http://localhost:3000
echo 3. 默认账号: admin/admin123
echo.
pause
goto :eof

:: ==================== 本地安装模式 ====================
:local_mode
echo.
echo [本地模式] 开始安装依赖...
echo.

:: 检查并安装Chocolatey（Windows包管理器）
where choco >nul 2>&1
if %errorlevel% neq 0 (
    echo [信息] 安装Chocolatey包管理器...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    set "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
)

:: 检查并安装Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [信息] 安装Node.js...
    choco install nodejs -y
    refreshenv
)

:: 检查并安装PostgreSQL
where psql >nul 2>&1
if %errorlevel% neq 0 (
    echo [信息] 安装PostgreSQL...
    choco install postgresql14 -y --params '/Password:postgres'
    refreshenv

    :: 创建数据库
    echo [信息] 创建数据库...
    set PGPASSWORD=postgres
    "C:\Program Files\PostgreSQL\14\bin\psql.exe" -U postgres -c "CREATE DATABASE flutter_unity_build;"
)

:: 安装Redis（使用Memurai - Windows版Redis）
where redis-cli >nul 2>&1
if %errorlevel% neq 0 (
    echo [信息] 安装Redis (Memurai)...
    echo.
    echo 请访问以下网址下载安装Memurai：
    echo https://www.memurai.com/get-memurai
    echo.
    echo 或者使用WSL安装Redis：
    echo wsl --install
    echo wsl sudo apt update
    echo wsl sudo apt install redis-server
    echo.
    start https://www.memurai.com/get-memurai
)

:: 检查Git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [信息] 安装Git...
    choco install git -y
    refreshenv
)

:: 安装项目依赖
echo [信息] 安装项目依赖...
call npm install -g pnpm
cd backend
call pnpm install
cd ..\frontend
call pnpm install
cd ..

:: 创建环境文件
echo [信息] 创建配置文件...
copy .env.windows.example .env

echo.
echo [成功] 本地模式安装完成！
echo.
echo 下一步：
echo 1. 编辑 .env 文件配置Unity和Flutter路径
echo 2. 运行: start.bat init （初始化数据库）
echo 3. 运行: start.bat dev （启动开发服务器）
echo.
pause
goto :eof

:: ==================== 轻量级模式（SQLite） ====================
:lite_mode
echo.
echo [轻量级模式] 配置SQLite版本...
echo.

:: 检查Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [信息] 下载Node.js安装包...
    echo 请访问 https://nodejs.org/ 下载并安装Node.js
    start https://nodejs.org/
    echo.
    echo 安装完成后请重新运行此脚本
    pause
    exit /b 1
)

:: 创建SQLite版本的配置
echo [信息] 创建SQLite配置...
call :create_sqlite_config

:: 安装依赖
echo [信息] 安装项目依赖...
cd backend
call npm install
call npm install sqlite3
cd ..\frontend
call npm install
cd ..

echo.
echo [成功] 轻量级模式配置完成！
echo.
echo 使用方法：
echo 1. 运行: start-lite.bat dev
echo 2. 访问: http://localhost:3000
echo 3. 默认账号: admin/admin123
echo.
echo 注意：轻量级模式使用SQLite数据库和内存缓存，仅适合开发测试
echo.
pause
goto :eof

:: ==================== 辅助函数 ====================

:create_docker_compose
(
echo version: '3.8'
echo.
echo services:
echo   postgres:
echo     image: postgres:14-alpine
echo     environment:
echo       POSTGRES_DB: flutter_unity_build
echo       POSTGRES_USER: postgres
echo       POSTGRES_PASSWORD: postgres
echo     volumes:
echo       - postgres_data:/var/lib/postgresql/data
echo     ports:
echo       - "5432:5432"
echo.
echo   redis:
echo     image: redis:7-alpine
echo     ports:
echo       - "6379:6379"
echo.
echo   backend:
echo     build: ./backend
echo     environment:
echo       DATABASE_URL: postgresql://postgres:postgres@postgres:5432/flutter_unity_build
echo       REDIS_URL: redis://redis:6379
echo       JWT_SECRET: your-secret-key-here
echo     ports:
echo       - "8000:8000"
echo     depends_on:
echo       - postgres
echo       - redis
echo     volumes:
echo       - ./artifacts:/app/artifacts
echo       - ./logs:/app/logs
echo       # Windows Unity/Flutter路径映射
echo       - C:/your/unity/project:/unity_repo
echo       - C:/your/flutter/project:/flutter_repo
echo.
echo   frontend:
echo     build: ./frontend
echo     ports:
echo       - "3000:3000"
echo     depends_on:
echo       - backend
echo     environment:
echo       NEXT_PUBLIC_API_URL: http://localhost:8000
echo.
echo volumes:
echo   postgres_data:
) > docker-compose.yml

:: 创建backend Dockerfile
(
echo FROM node:18-alpine
echo.
echo WORKDIR /app
echo.
echo COPY package*.json ./
echo RUN npm ci --only=production
echo.
echo COPY prisma ./prisma
echo RUN npx prisma generate
echo.
echo COPY . .
echo RUN npm run build
echo.
echo EXPOSE 8000
echo CMD ["npm", "start"]
) > backend\Dockerfile

:: 创建frontend Dockerfile
(
echo FROM node:18-alpine
echo.
echo WORKDIR /app
echo.
echo COPY package*.json ./
echo RUN npm ci
echo.
echo COPY . .
echo RUN npm run build
echo.
echo EXPOSE 3000
echo CMD ["npm", "start"]
) > frontend\Dockerfile
goto :eof

:create_sqlite_config
:: 创建SQLite版本的环境文件
(
echo # SQLite轻量级配置
echo NODE_ENV=development
echo PORT=8000
echo.
echo # Security
echo JWT_SECRET=dev-secret-key-change-in-production
echo JWT_EXPIRE=7d
echo.
echo # Database - 使用SQLite
echo DATABASE_URL=file:./dev.db
echo DATABASE_TYPE=sqlite
echo.
echo # Redis - 使用内存缓存
echo USE_REDIS=false
echo.
echo # Frontend
echo FRONTEND_URL=http://localhost:3000
echo.
echo # Unity配置 - 请修改为你的路径
echo UNITY_EDITOR_PATH=C:\Program Files\Unity\Hub\Editor\2022.3.10f1\Editor\Unity.exe
echo UNITY_REPO_PATH=C:\unity_project
echo UNITY_REPO_URL=
echo.
echo # Flutter配置 - 请修改为你的路径
echo FLUTTER_SDK_PATH=C:\flutter
echo FLUTTER_REPO_PATH=C:\flutter_project
echo FLUTTER_REPO_URL=
echo.
echo # 构建设置
echo BUILD_TIMEOUT=3600000
echo MAX_CONCURRENT_BUILDS=1
) > .env.lite

:: 创建轻量级启动脚本
(
echo @echo off
echo.
echo :: 轻量级模式启动脚本
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