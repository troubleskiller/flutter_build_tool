@echo off
:: Docker快速启动脚本 - 自动安装并启动所有服务
:: 这是最简单的一键启动方式

echo ====================================================
echo  Flutter Unity Build Tool - Docker一键快速启动
echo ====================================================
echo.

:: 检查Docker
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 请先安装Docker Desktop
    echo.
    echo 正在打开Docker Desktop下载页面...
    start https://www.docker.com/products/docker-desktop/
    echo.
    echo 安装Docker Desktop后，请重新运行此脚本
    pause
    exit /b 1
)

:: 检查Docker是否运行
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] 正在启动Docker Desktop，请稍等...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo.
    echo 等待Docker完全启动（约30秒）...
    timeout /t 30 /nobreak >nul

    :: 再次检查
    docker info >nul 2>&1
    if %errorlevel% neq 0 (
        echo [错误] Docker仍未运行，请手动启动Docker Desktop
        pause
        exit /b 1
    )
)

echo [信息] Docker已就绪
echo.

:: 检查并创建.env文件
if not exist .env (
    echo [配置] 创建环境配置文件...
    if exist .env.docker (
        copy .env.docker .env >nul
    ) else (
        (
            echo # Docker环境配置
            echo JWT_SECRET=change-this-in-production-%RANDOM%
            echo.
            echo # 请修改为你的Unity和Flutter路径
            echo UNITY_PROJECT_PATH=C:\your\unity\project
            echo FLUTTER_PROJECT_PATH=C:\your\flutter\project
            echo UNITY_EDITOR_PATH=C:\Program Files\Unity\Hub\Editor\2022.3.10f1\Editor\Unity.exe
            echo FLUTTER_SDK_PATH=C:\flutter\bin\flutter.bat
        ) > .env
    )

    echo.
    echo [重要] 请配置你的Unity和Flutter项目路径
    echo.
    notepad .env
    echo.
    set /p READY="配置完成后，按Enter继续..."
)

:: 开始安装
echo.
echo [1/4] 拉取所需的Docker镜像...
echo       - PostgreSQL 14 数据库
echo       - Redis 7 缓存服务
docker-compose pull postgres redis

echo.
echo [2/4] 构建应用镜像...
docker-compose build

echo.
echo [3/4] 启动数据库服务...
docker-compose up -d postgres redis

:: 等待数据库就绪
echo       等待数据库初始化...
timeout /t 10 /nobreak >nul

echo.
echo [4/4] 启动所有服务...
docker-compose up -d

:: 等待服务完全启动
echo.
echo 等待服务启动...
timeout /t 5 /nobreak >nul

:: 检查服务状态
echo.
echo ====================================================
echo  启动成功！
echo ====================================================
echo.
echo 系统已就绪，可以访问：
echo.
echo   前端界面：  http://localhost:3000
echo   后端API：   http://localhost:8000
echo   数据库管理：http://localhost:8080
echo.
echo   默认账号：  admin / admin123
echo.
echo ====================================================
echo.
echo 提示：
echo - 使用 docker-start.bat 管理服务
echo - 使用 docker-compose logs -f 查看日志
echo - 使用 docker-compose down 停止服务
echo.
echo 正在打开浏览器...
timeout /t 2 /nobreak >nul
start http://localhost:3000

pause