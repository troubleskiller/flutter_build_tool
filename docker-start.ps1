# Docker启动脚本 - PowerShell版本
# 自动拉取并配置PostgreSQL和Redis

Write-Host "================================================" -ForegroundColor Cyan
Write-Host " Flutter Unity Build Tool - Docker一键启动" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# 检查Docker是否安装
$dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerInstalled) {
    Write-Host "[错误] Docker未安装！" -ForegroundColor Red
    Write-Host ""
    Write-Host "请先安装Docker Desktop:" -ForegroundColor Yellow
    Write-Host "https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "按Enter键退出"
    exit 1
}

# 检查Docker是否运行
try {
    docker info | Out-Null
} catch {
    Write-Host "[错误] Docker未运行！" -ForegroundColor Red
    Write-Host "请启动Docker Desktop后重试" -ForegroundColor Yellow
    Read-Host "按Enter键退出"
    exit 1
}

# 检查.env文件
if (-not (Test-Path .env)) {
    Write-Host "[信息] 创建环境配置文件..." -ForegroundColor Green
    Copy-Item .env.docker .env
    Write-Host ""
    Write-Host "[重要] 请编辑 .env 文件，配置你的Unity和Flutter路径" -ForegroundColor Yellow
    Write-Host ""
    notepad .env
    Read-Host "配置完成后按Enter继续"
}

# 显示菜单
function Show-Menu {
    Write-Host ""
    Write-Host "请选择操作:" -ForegroundColor Green
    Write-Host "1. 首次安装并启动" -ForegroundColor Cyan
    Write-Host "2. 启动服务" -ForegroundColor Cyan
    Write-Host "3. 停止服务" -ForegroundColor Cyan
    Write-Host "4. 重启服务" -ForegroundColor Cyan
    Write-Host "5. 查看日志" -ForegroundColor Cyan
    Write-Host "6. 清理所有数据（危险）" -ForegroundColor Red
    Write-Host "7. 更新并重建" -ForegroundColor Cyan
    Write-Host "0. 退出" -ForegroundColor Gray
    Write-Host ""
}

# 首次安装
function Install-Services {
    Write-Host ""
    Write-Host "[步骤1/5] 拉取Docker镜像..." -ForegroundColor Green
    docker-compose pull
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 拉取镜像失败" -ForegroundColor Red
        Read-Host "按Enter键退出"
        exit 1
    }

    Write-Host ""
    Write-Host "[步骤2/5] 构建应用镜像..." -ForegroundColor Green
    docker-compose build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 构建失败" -ForegroundColor Red
        Read-Host "按Enter键退出"
        exit 1
    }

    Write-Host ""
    Write-Host "[步骤3/5] 启动PostgreSQL和Redis..." -ForegroundColor Green
    docker-compose up -d postgres redis
    Start-Sleep -Seconds 10

    Write-Host ""
    Write-Host "[步骤4/5] 初始化数据库..." -ForegroundColor Green
    docker-compose exec -T backend npx prisma migrate deploy
    docker-compose exec -T backend npx prisma db seed

    Write-Host ""
    Write-Host "[步骤5/5] 启动所有服务..." -ForegroundColor Green
    docker-compose up -d

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host " 安装完成！" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "前端地址: http://localhost:3000" -ForegroundColor Cyan
    Write-Host "后端地址: http://localhost:8000" -ForegroundColor Cyan
    Write-Host "数据库管理: http://localhost:8080" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "默认账号: admin / admin123" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "使用 docker-start.ps1 管理服务" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
}

# 启动服务
function Start-Services {
    Write-Host ""
    Write-Host "[信息] 启动服务..." -ForegroundColor Green
    docker-compose up -d
    Write-Host ""
    Write-Host "服务已启动:" -ForegroundColor Green
    Write-Host "- 前端: http://localhost:3000" -ForegroundColor Cyan
    Write-Host "- 后端: http://localhost:8000" -ForegroundColor Cyan
    Write-Host "- 数据库管理: http://localhost:8080" -ForegroundColor Cyan
}

# 停止服务
function Stop-Services {
    Write-Host ""
    Write-Host "[信息] 停止服务..." -ForegroundColor Yellow
    docker-compose down
    Write-Host "服务已停止" -ForegroundColor Green
}

# 重启服务
function Restart-Services {
    Write-Host ""
    Write-Host "[信息] 重启服务..." -ForegroundColor Yellow
    docker-compose restart
    Write-Host "服务已重启" -ForegroundColor Green
}

# 查看日志
function Show-Logs {
    Write-Host ""
    Write-Host "选择查看日志:" -ForegroundColor Green
    Write-Host "1. 所有服务" -ForegroundColor Cyan
    Write-Host "2. 后端" -ForegroundColor Cyan
    Write-Host "3. 前端" -ForegroundColor Cyan
    Write-Host "4. PostgreSQL" -ForegroundColor Cyan
    Write-Host "5. Redis" -ForegroundColor Cyan
    $logChoice = Read-Host "请选择 (1-5)"

    switch ($logChoice) {
        "1" { docker-compose logs -f }
        "2" { docker-compose logs -f backend }
        "3" { docker-compose logs -f frontend }
        "4" { docker-compose logs -f postgres }
        "5" { docker-compose logs -f redis }
    }
}

# 清理数据
function Clean-Data {
    Write-Host ""
    Write-Host "[警告] 此操作将删除所有数据！" -ForegroundColor Red
    $confirm = Read-Host "确认删除? (yes/no)"
    if ($confirm -eq "yes") {
        docker-compose down -v
        Write-Host "所有数据已清理" -ForegroundColor Green
    } else {
        Write-Host "操作已取消" -ForegroundColor Yellow
    }
}

# 更新并重建
function Rebuild-Services {
    Write-Host ""
    Write-Host "[信息] 更新并重建服务..." -ForegroundColor Green
    docker-compose down
    docker-compose pull
    docker-compose build --no-cache
    docker-compose up -d
    Write-Host "服务已更新并重启" -ForegroundColor Green
}

# 主循环
do {
    Show-Menu
    $choice = Read-Host "请输入选项"

    switch ($choice) {
        "1" { Install-Services }
        "2" { Start-Services }
        "3" { Stop-Services }
        "4" { Restart-Services }
        "5" { Show-Logs }
        "6" { Clean-Data }
        "7" { Rebuild-Services }
        "0" {
            Write-Host "再见！" -ForegroundColor Green
            exit 0
        }
        default {
            Write-Host "无效选项，请重新选择" -ForegroundColor Red
        }
    }

    if ($choice -ne "0" -and $choice -ne "5") {
        Write-Host ""
        Read-Host "按Enter键返回菜单"
    }
} while ($choice -ne "0")