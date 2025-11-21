@echo off
setlocal enabledelayedexpansion

:: Docker启动脚本 - 自动拉取并配置PostgreSQL和Redis

echo ================================================
echo  Flutter Unity Build Tool - Docker一键启动
echo ================================================
echo.

:: 检查Docker是否安装
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Docker未安装！
    echo.
    echo 请先安装Docker Desktop:
    echo https://www.docker.com/products/docker-desktop/
    echo.
    pause
    exit /b 1
)

:: 检查Docker是否运行
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Docker未运行！
    echo 请启动Docker Desktop后重试
    pause
    exit /b 1
)

:: 检查.env文件
if not exist .env (
    echo [信息] 创建环境配置文件...
    copy .env.docker .env >nul 2>&1
    echo.
    echo [重要] 请编辑 .env 文件，配置你的Unity和Flutter路径
    echo.
    notepad .env
    pause
)

:: 选择操作
echo 请选择操作:
echo 1. 首次安装并启动
echo 2. 启动服务
echo 3. 停止服务
echo 4. 重启服务
echo 5. 查看日志
echo 6. 清理所有数据（危险）
echo 7. 更新并重建
echo.
set /p ACTION="请输入选项 (1-7): "

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
echo [步骤1/5] 拉取Docker镜像...
docker-compose pull
if %errorlevel% neq 0 (
    echo [错误] 拉取镜像失败
    pause
    exit /b 1
)

echo.
echo [步骤2/5] 构建应用镜像...
docker-compose build
if %errorlevel% neq 0 (
    echo [错误] 构建失败
    pause
    exit /b 1
)

echo.
echo [步骤3/5] 启动PostgreSQL和Redis...
docker-compose up -d postgres redis
timeout /t 10 >nul

echo.
echo [步骤4/5] 初始化数据库...
docker-compose exec -T backend npx prisma migrate deploy
docker-compose exec -T backend npx prisma db seed

echo.
echo [步骤5/5] 启动所有服务...
docker-compose up -d

echo.
echo ================================================
echo  安装完成！
echo ================================================
echo.
echo 前端地址: http://localhost:3000
echo 后端地址: http://localhost:8000
echo 数据库管理: http://localhost:8080
echo.
echo 默认账号: admin / admin123
echo.
echo 使用 docker-start.bat 管理服务
echo ================================================
pause
goto :eof

:start
echo.
echo [信息] 启动服务...
docker-compose up -d
echo.
echo 服务已启动:
echo - 前端: http://localhost:3000
echo - 后端: http://localhost:8000
echo - 数据库管理: http://localhost:8080
pause
goto :eof

:stop
echo.
echo [信息] 停止服务...
docker-compose down
echo 服务已停止
pause
goto :eof

:restart
echo.
echo [信息] 重启服务...
docker-compose restart
echo 服务已重启
pause
goto :eof

:logs
echo.
echo 选择查看日志:
echo 1. 所有服务
echo 2. 后端
echo 3. 前端
echo 4. PostgreSQL
echo 5. Redis
set /p LOG_CHOICE="请选择 (1-5): "

if "%LOG_CHOICE%"=="1" docker-compose logs -f
if "%LOG_CHOICE%"=="2" docker-compose logs -f backend
if "%LOG_CHOICE%"=="3" docker-compose logs -f frontend
if "%LOG_CHOICE%"=="4" docker-compose logs -f postgres
if "%LOG_CHOICE%"=="5" docker-compose logs -f redis
goto :eof

:clean
echo.
echo [警告] 此操作将删除所有数据！
set /p CONFIRM="确认删除? (yes/no): "
if /i "%CONFIRM%"=="yes" (
    docker-compose down -v
    echo 所有数据已清理
) else (
    echo 操作已取消
)
pause
goto :eof

:rebuild
echo.
echo [信息] 更新并重建服务...
docker-compose down
docker-compose pull
docker-compose build --no-cache
docker-compose up -d
echo 服务已更新并重启
pause
goto :eof

endlocal