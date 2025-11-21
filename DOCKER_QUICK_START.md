# Docker快速开始指南

## 一键启动（Windows）

你无需安装PostgreSQL、Redis或其他依赖，Docker会自动为你拉取和配置一切！

### 1. 安装Docker Desktop

如果还没有安装Docker Desktop，请访问：
https://www.docker.com/products/docker-desktop/

### 2. 配置环境

```batch
# 复制环境配置模板
copy .env.docker .env

# 编辑.env文件，设置你的Unity和Flutter路径
notepad .env
```

**重要配置项：**
- `UNITY_PROJECT_PATH`: 你的Unity项目路径
- `FLUTTER_PROJECT_PATH`: 你的Flutter项目路径
- `UNITY_EDITOR_PATH`: Unity编辑器exe路径
- `FLUTTER_SDK_PATH`: Flutter SDK路径

### 3. 一键启动

```batch
# 运行Docker启动脚本
docker-start.bat

# 选择 1 (首次安装并启动)
```

脚本会自动：
- ✅ 拉取PostgreSQL 14镜像
- ✅ 拉取Redis 7镜像
- ✅ 构建前端和后端镜像
- ✅ 初始化数据库
- ✅ 启动所有服务

### 4. 访问系统

安装完成后，可以访问：
- 🌐 前端界面：http://localhost:3000
- 🔧 后端API：http://localhost:8000
- 📊 数据库管理：http://localhost:8080
- 默认账号：**admin / admin123**

## 管理命令

使用 `docker-start.bat` 管理服务：

```batch
# 启动服务
docker-start.bat
选择 2

# 停止服务
docker-start.bat
选择 3

# 查看日志
docker-start.bat
选择 5

# 重建服务（更新代码后）
docker-start.bat
选择 7
```

## Docker Compose命令

你也可以直接使用docker-compose命令：

```batch
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 查看日志
docker-compose logs -f

# 只启动数据库和Redis
docker-compose up -d postgres redis

# 重建并启动
docker-compose up -d --build
```

## 服务说明

Docker Compose会启动以下服务：

| 服务 | 说明 | 端口 | 容器名 |
|------|------|------|--------|
| postgres | PostgreSQL 14数据库 | 5432 | flutter_build_postgres |
| redis | Redis 7缓存服务 | 6379 | flutter_build_redis |
| backend | Node.js后端服务 | 8000 | flutter_build_backend |
| frontend | Next.js前端服务 | 3000 | flutter_build_frontend |
| adminer | 数据库管理界面 | 8080 | flutter_build_adminer |

## 数据持久化

Docker使用卷（volumes）来持久化数据：
- `postgres_data`: PostgreSQL数据
- `redis_data`: Redis数据
- `./artifacts`: 构建产物
- `./logs`: 日志文件

## 故障排除

### Docker未启动
```batch
# 确保Docker Desktop正在运行
# 在系统托盘查看Docker图标
```

### 端口被占用
```batch
# 查看占用端口的进程
netstat -ano | findstr :3000
netstat -ano | findstr :8000

# 结束占用进程
taskkill /PID [进程ID] /F
```

### 清理并重新开始
```batch
# 停止并删除所有容器和卷（危险！会删除数据）
docker-compose down -v

# 重新构建
docker-compose build --no-cache

# 启动
docker-compose up -d
```

### 查看容器状态
```batch
# 查看所有容器
docker ps

# 查看容器日志
docker logs flutter_build_backend
docker logs flutter_build_frontend
```

## 开发模式

如果你需要在开发时实时修改代码：

1. 修改 `docker-compose.yml`，添加代码映射：
```yaml
backend:
  volumes:
    - ./backend/src:/app/src
    - ./backend/prisma:/app/prisma
```

2. 使用开发命令启动：
```batch
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

## 生产部署

生产环境部署时，请：
1. 修改`.env`中的`JWT_SECRET`
2. 使用强密码替换默认的数据库密码
3. 配置HTTPS（可以使用nginx反向代理）
4. 限制数据库端口访问（不对外开放5432和6379）

---

现在你可以开始使用了！无需安装任何数据库或依赖，Docker会处理一切！