# Flutter Unity Build Tool - Docker完整解决方案

## 🚀 一键启动（无需安装任何依赖）

这个Docker解决方案会自动为你拉取并配置所有需要的服务，包括：
- PostgreSQL 14 数据库
- Redis 7 缓存服务
- Node.js 后端服务
- Next.js 前端服务

**你不需要在本地安装PostgreSQL、Redis或其他任何依赖！**

## 📋 系统要求

你只需要：
1. Windows 10/11（或Mac/Linux）
2. Docker Desktop（[下载链接](https://www.docker.com/products/docker-desktop/)）
3. Unity项目路径
4. Flutter项目路径

## 🎯 快速开始

### 1️⃣ 准备配置

```bash
# 复制环境配置模板
copy .env.docker .env

# 编辑配置文件（会自动打开记事本）
notepad .env
```

**必须配置的路径：**
```env
# Unity项目路径（你的Unity项目文件夹）
UNITY_PROJECT_PATH=C:\your\unity\project

# Flutter项目路径（你的Flutter项目文件夹）
FLUTTER_PROJECT_PATH=C:\your\flutter\project

# Unity编辑器路径
UNITY_EDITOR_PATH=C:\Program Files\Unity\Hub\Editor\2022.3.10f1\Editor\Unity.exe

# Flutter SDK路径
FLUTTER_SDK_PATH=C:\flutter\bin\flutter.bat
```

### 2️⃣ 一键安装启动

**使用批处理脚本（推荐）：**
```bash
docker-start.bat
# 选择 1 (首次安装并启动)
```

**或使用PowerShell脚本：**
```powershell
.\docker-start.ps1
# 选择 1 (首次安装并启动)
```

脚本会自动完成以下操作：
- ✅ 拉取PostgreSQL 14数据库镜像
- ✅ 拉取Redis 7缓存镜像
- ✅ 构建后端服务镜像
- ✅ 构建前端服务镜像
- ✅ 初始化数据库表结构
- ✅ 创建默认管理员账号
- ✅ 启动所有服务

### 3️⃣ 访问系统

安装完成后，打开浏览器访问：
- 🌐 **前端界面**: http://localhost:3000
- 🔧 **后端API**: http://localhost:8000
- 📊 **数据库管理**: http://localhost:8080
- 👤 **默认账号**: admin / admin123

## 📦 包含的服务

| 服务 | 说明 | 端口 | 访问地址 |
|------|------|------|----------|
| Frontend | Next.js前端界面 | 3000 | http://localhost:3000 |
| Backend | Node.js后端API | 8000 | http://localhost:8000 |
| PostgreSQL | 数据库服务 | 5432 | localhost:5432 |
| Redis | 缓存服务 | 6379 | localhost:6379 |
| Adminer | 数据库管理工具 | 8080 | http://localhost:8080 |

## 🛠 日常使用

### 启动/停止服务

```bash
# 使用脚本管理（推荐）
docker-start.bat

# 或直接使用docker-compose命令
docker-compose up -d    # 启动所有服务
docker-compose down     # 停止所有服务
docker-compose restart  # 重启所有服务
```

### 查看日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f postgres
```

### 更新代码后重建

```bash
# 使用脚本
docker-start.bat
# 选择 7 (更新并重建)

# 或手动重建
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 🗂 数据持久化

Docker使用卷（volumes）来持久化数据，即使容器重启数据也不会丢失：

- `postgres_data`: PostgreSQL数据库文件
- `redis_data`: Redis缓存数据
- `./artifacts`: 构建的APK文件
- `./logs`: 应用日志文件

## ⚙️ 高级配置

### 修改端口

如果默认端口被占用，编辑 `docker-compose.yml`：

```yaml
services:
  frontend:
    ports:
      - "3001:3000"  # 改为3001端口
  backend:
    ports:
      - "8001:8000"  # 改为8001端口
```

### 使用自定义数据库密码

编辑 `.env` 文件：

```env
POSTGRES_PASSWORD=your_strong_password
```

然后更新 `docker-compose.yml` 中的连接字符串。

## 🔧 故障排除

### 问题：Docker Desktop未启动

**解决方案：**
1. 确保Docker Desktop正在运行
2. 在系统托盘查看Docker图标
3. 等待Docker完全启动后再运行脚本

### 问题：端口被占用

**解决方案：**
```bash
# 查看占用端口的进程
netstat -ano | findstr :3000

# 结束进程
taskkill /PID [进程ID] /F

# 或修改docker-compose.yml中的端口
```

### 问题：构建失败

**解决方案：**
```bash
# 清理Docker缓存
docker system prune -a

# 重新构建
docker-compose build --no-cache
```

### 问题：数据库连接失败

**解决方案：**
```bash
# 检查PostgreSQL容器状态
docker ps | findstr postgres

# 查看PostgreSQL日志
docker logs flutter_build_postgres

# 重新初始化数据库
docker-compose down -v
docker-compose up -d
```

## 📝 开发模式

如果需要在开发时实时修改代码（热重载）：

1. 创建 `docker-compose.dev.yml`:
```yaml
version: '3.8'
services:
  backend:
    volumes:
      - ./backend/src:/app/src
    environment:
      NODE_ENV: development
    command: npm run dev

  frontend:
    volumes:
      - ./frontend:/app
    command: npm run dev
```

2. 启动开发模式：
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

## 🔒 生产部署

生产环境部署时的注意事项：

1. **修改密钥和密码**
   - 修改 `.env` 中的 `JWT_SECRET`
   - 修改数据库密码
   - 修改默认管理员密码

2. **配置HTTPS**
   - 使用nginx反向代理
   - 配置SSL证书

3. **限制端口访问**
   - 不对外暴露5432（PostgreSQL）
   - 不对外暴露6379（Redis）
   - 只暴露80/443端口

4. **备份策略**
   ```bash
   # 备份数据库
   docker exec flutter_build_postgres pg_dump -U postgres flutter_unity_build > backup.sql

   # 恢复数据库
   docker exec -i flutter_build_postgres psql -U postgres flutter_unity_build < backup.sql
   ```

## 💡 提示

1. **Docker会自动处理所有依赖**，你不需要安装PostgreSQL、Redis等
2. **数据会持久保存**，即使重启Docker也不会丢失
3. **可以随时查看数据库**，访问 http://localhost:8080 使用Adminer
4. **支持多平台**，相同的配置可以在Windows、Mac、Linux上运行

## 📞 需要帮助？

如果遇到问题：
1. 查看日志：`docker-compose logs`
2. 检查容器状态：`docker ps`
3. 查看Docker快速开始指南：`DOCKER_QUICK_START.md`

---

现在你可以开始使用了！Docker会自动为你处理所有的PostgreSQL、Redis等服务配置！