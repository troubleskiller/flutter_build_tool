# Flutter Unity Build Tool 部署指南

## 系统要求

### 软件要求
- **操作系统**: Ubuntu 20.04+ / macOS 11+ / Windows 10+
- **Python**: 3.9+
- **Node.js**: 18+
- **PostgreSQL**: 14+
- **Redis**: 6+
- **Unity Editor**: 2022.3+
- **Flutter SDK**: 3.0+
- **Git**: 2.25+

### 硬件要求
- **CPU**: 4核心以上
- **内存**: 16GB以上（Unity构建需要大量内存）
- **存储**: 100GB以上可用空间

## 快速开始

### 1. 克隆项目
```bash
git clone <repository-url>
cd flutter_build_tool
```

### 2. 安装依赖
```bash
# 给启动脚本添加执行权限
chmod +x start.sh

# 安装所有依赖
./start.sh install
```

### 3. 配置环境变量
编辑 `.env` 文件，配置以下关键参数：

```bash
# 数据库连接
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/flutter_unity_build

# Redis连接
REDIS_URL=redis://localhost:6379/0

# Unity配置
UNITY_EDITOR_PATH=/path/to/Unity
UNITY_REPO_URL=https://github.com/your-org/unity-project.git

# Flutter配置
FLUTTER_SDK_PATH=/path/to/flutter
FLUTTER_REPO_URL=https://github.com/your-org/flutter-project.git
```

### 4. 初始化数据库
```bash
# 创建数据库
createdb flutter_unity_build

# 初始化表结构
./start.sh init
```

### 5. 启动应用
```bash
# 开发模式启动（包含前端、后端、Redis）
./start.sh dev
```

应用启动后可以访问：
- 前端界面: http://localhost:3000
- 后端API: http://localhost:8000
- API文档: http://localhost:8000/docs

## 详细安装步骤

### PostgreSQL 安装

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# 创建数据库和用户
sudo -u postgres psql
CREATE DATABASE flutter_unity_build;
CREATE USER builduser WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE flutter_unity_build TO builduser;
\q
```

#### macOS
```bash
brew install postgresql
brew services start postgresql
createdb flutter_unity_build
```

### Redis 安装

#### Ubuntu/Debian
```bash
sudo apt install redis-server
sudo systemctl start redis
sudo systemctl enable redis
```

#### macOS
```bash
brew install redis
brew services start redis
```

### Unity Editor 安装

1. 下载 Unity Hub: https://unity.com/download
2. 通过 Unity Hub 安装指定版本的 Unity Editor（建议 2022.3 LTS）
3. 记录 Unity Editor 的安装路径，配置到 `.env` 文件中

### Flutter SDK 安装

1. 下载 Flutter SDK: https://flutter.dev/docs/get-started/install
2. 解压到指定目录
3. 添加 Flutter 到系统 PATH
4. 运行 `flutter doctor` 确保环境正确

## 生产环境部署

### 使用 Docker Compose

创建 `docker-compose.yml` 文件：

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: flutter_unity_build
      POSTGRES_USER: builduser
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:6-alpine
    ports:
      - "6379:6379"

  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgresql+asyncpg://builduser:${DB_PASSWORD}@postgres:5432/flutter_unity_build
      REDIS_URL: redis://redis:6379/0
    ports:
      - "8000:8000"
    depends_on:
      - postgres
      - redis
    volumes:
      - ./artifacts:/app/artifacts
      - ./logs:/app/logs

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    depends_on:
      - backend
    environment:
      NEXT_PUBLIC_API_URL: http://backend:8000

volumes:
  postgres_data:
```

### 使用 Nginx 反向代理

创建 Nginx 配置文件：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # 前端
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # 后端API
    location /api {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
    }

    # WebSocket
    location /ws {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    # 静态文件（APK下载）
    location /artifacts {
        alias /var/www/flutter_build_tool/artifacts;
        autoindex off;
    }
}
```

### 使用 systemd 服务

创建后端服务文件 `/etc/systemd/system/flutter-build-backend.service`:

```ini
[Unit]
Description=Flutter Unity Build Tool Backend
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/flutter_build_tool/backend
Environment="PATH=/opt/flutter_build_tool/backend/venv/bin"
ExecStart=/opt/flutter_build_tool/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable flutter-build-backend
sudo systemctl start flutter-build-backend
```

## 监控和维护

### 日志查看
```bash
# 查看后端日志
tail -f logs/backend.log

# 查看构建日志
tail -f logs/builds/*.log

# 查看systemd服务日志
journalctl -u flutter-build-backend -f
```

### 数据库备份
```bash
# 备份数据库
pg_dump flutter_unity_build > backup_$(date +%Y%m%d).sql

# 恢复数据库
psql flutter_unity_build < backup_20231201.sql
```

### 清理旧产物
```bash
# 手动清理30天前的产物
find artifacts/ -type f -mtime +30 -delete

# 或者通过管理界面配置自动清理策略
```

## 故障排查

### 常见问题

1. **数据库连接失败**
   - 检查PostgreSQL服务是否运行
   - 验证数据库连接字符串
   - 确认防火墙设置

2. **Redis连接失败**
   - 检查Redis服务是否运行
   - 验证Redis连接字符串
   - 检查Redis配置文件

3. **Unity构建失败**
   - 验证Unity Editor路径
   - 检查Unity许可证
   - 查看Unity日志文件

4. **Flutter构建失败**
   - 运行 `flutter doctor`
   - 检查Flutter SDK路径
   - 验证Android SDK配置

## 性能优化

### 数据库优化
```sql
-- 添加索引
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_created_at ON tasks(created_at);
CREATE INDEX idx_artifacts_created_at ON artifacts(created_at);
```

### Redis优化
```bash
# 编辑 /etc/redis/redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
```

### 构建优化
- 使用SSD存储提高IO性能
- 增加内存减少构建时间
- 配置构建缓存目录
- 使用增量构建

## 安全建议

1. **使用HTTPS**
   - 配置SSL证书
   - 强制HTTPS重定向

2. **限制访问**
   - 配置防火墙规则
   - 使用VPN访问内部服务

3. **定期更新**
   - 更新系统依赖
   - 更新应用依赖
   - 应用安全补丁

4. **备份策略**
   - 定期备份数据库
   - 备份配置文件
   - 备份构建产物

## 联系支持

如有问题，请联系技术支持团队或查看项目Wiki。