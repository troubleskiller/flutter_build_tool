# Flutter + Unity 打包工具

## 项目简介
这是一个用于自动化构建 Unity 和 Flutter 项目的 Web 工具，提供了完整的任务管理、实时日志、产物下载等功能。

## 技术栈
- **前端**: Next.js 14, TypeScript, Tailwind CSS, shadcn/ui
- **后端**: Node.js, Express, TypeScript, Prisma ORM
- **数据库**: PostgreSQL
- **缓存**: Redis
- **实时通信**: Socket.io
- **任务执行**: Shell scripts

## 项目结构
```
flutter_build_tool/
├── frontend/               # Next.js 前端应用
│   ├── app/               # 应用页面和布局
│   ├── components/        # React 组件
│   ├── lib/              # 工具函数
│   └── package.json
│
├── backend/               # Node.js Express 后端
│   ├── src/
│   │   ├── config/       # 配置文件
│   │   ├── controllers/  # 控制器
│   │   ├── middlewares/  # 中间件
│   │   ├── routes/       # API 路由
│   │   ├── services/     # 业务逻辑服务
│   │   ├── utils/        # 工具函数
│   │   └── scripts/      # Shell 脚本
│   ├── prisma/           # Prisma 数据库模型
│   └── package.json
│
├── artifacts/            # 构建产物存储
├── logs/                 # 日志文件
└── docs/                 # 文档
```

## 功能特点
1. **任务管理**
   - 全局互斥锁保证单任务执行
   - 任务队列管理
   - 实时状态更新

2. **构建流程**
   - Unity 分支选择和更新
   - Unity 导出到 Flutter
   - Flutter 分支选择和更新
   - Flutter APK 构建

3. **日志系统**
   - 实时日志流式传输 (WebSocket)
   - 历史日志查询
   - 错误日志下载

4. **产物管理**
   - APK 文件持久化存储
   - 版本管理和下载
   - 清理策略配置

5. **统计分析**
   - 构建成功率统计
   - 耗时分析
   - 用户活动追踪

## 快速开始

### 环境要求
- Node.js 18+
- PostgreSQL 14+
- Redis 6+
- Unity Editor
- Flutter SDK

### 安装步骤

1. 克隆仓库
```bash
git clone [repository-url]
cd flutter_build_tool
```

2. 安装依赖
```bash
chmod +x start.sh
./start.sh install
```

3. 配置环境变量
```bash
cp .env.example .env
# 编辑 .env 文件配置数据库、Redis、Unity、Flutter 等路径
```

4. 初始化数据库
```bash
# 创建数据库
createdb flutter_unity_build

# 初始化表结构和种子数据
./start.sh init
```

5. 启动应用
```bash
# 开发模式
./start.sh dev

# 生产模式
./start.sh production
```

应用启动后可以访问：
- 前端界面: http://localhost:3000
- 后端API: http://localhost:8000
- 默认管理员: admin/admin123
- 默认用户: test/test123

## API 路由

### 认证 `/api/v1/auth`
- POST `/register` - 用户注册
- POST `/login` - 用户登录
- GET `/me` - 获取当前用户信息
- POST `/change-password` - 修改密码

### 任务 `/api/v1/tasks`
- POST `/create` - 创建构建任务
- GET `/current` - 获取当前运行任务
- GET `/list` - 获取任务列表
- GET `/:id` - 获取任务详情
- POST `/:id/cancel` - 取消任务
- GET `/:id/logs` - 获取任务日志
- GET `/queue/status` - 获取队列状态

### 产物 `/api/v1/artifacts`
- GET `/list` - 获取产物列表
- GET `/:id` - 获取产物详情
- GET `/:id/download` - 下载产物
- POST `/:id/archive` - 归档产物
- DELETE `/:id` - 删除产物 (管理员)

### 统计 `/api/v1/statistics`
- GET `/summary` - 获取统计摘要
- GET `/by-branch` - 按分支统计
- GET `/time-series` - 时间序列数据
- GET `/top-users` - 活跃用户排行

### 配置 `/api/v1/config`
- GET `/repos` - 获取仓库配置
- POST `/repos` - 更新仓库配置 (管理员)
- GET `/repos/:type/branches` - 获取仓库分支
- GET `/cleanup-policies` - 获取清理策略
- POST `/cleanup-policies` - 创建清理策略 (管理员)

## 开发指南

### 后端开发

```bash
cd backend
npm run dev        # 启动开发服务器
npm run build      # 构建 TypeScript
npm run start      # 启动生产服务器
```

### 前端开发

```bash
cd frontend
npm run dev        # 启动开发服务器
npm run build      # 构建生产版本
npm run start      # 启动生产服务器
```

### 数据库操作

```bash
cd backend
npx prisma migrate dev     # 创建新迁移
npx prisma generate        # 生成 Prisma 客户端
npx prisma studio          # 打开数据库管理界面
npm run prisma:seed        # 运行种子数据
```

## 部署指南

### 使用 PM2

```bash
# 安装 PM2
npm install -g pm2

# 构建项目
./start.sh build

# 启动服务
pm2 start ecosystem.config.js

# 查看状态
pm2 status

# 查看日志
pm2 logs
```

### 使用 Docker

```bash
# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f
```

## 配置说明

### 环境变量

查看 `.env.example` 文件了解所有可配置项：

- `DATABASE_URL` - PostgreSQL 连接字符串
- `REDIS_URL` - Redis 连接字符串
- `JWT_SECRET` - JWT 密钥
- `UNITY_EDITOR_PATH` - Unity 编辑器路径
- `FLUTTER_SDK_PATH` - Flutter SDK 路径
- `UNITY_REPO_URL` - Unity 仓库地址
- `FLUTTER_REPO_URL` - Flutter 仓库地址

### 清理策略

- 自动清理超过指定天数的产物
- 保留最近 N 个构建产物
- 可配置归档策略

## 故障排查

### 常见问题

1. **数据库连接失败**
   - 检查 PostgreSQL 服务是否运行
   - 验证数据库连接字符串

2. **Redis 连接失败**
   - 检查 Redis 服务是否运行
   - 验证 Redis 连接字符串

3. **Unity 构建失败**
   - 验证 Unity Editor 路径
   - 检查 Unity 许可证
   - 查看构建日志

4. **Flutter 构建失败**
   - 运行 `flutter doctor`
   - 检查 Flutter SDK 路径
   - 验证 Android SDK 配置

## 贡献指南

欢迎提交 Issue 和 Pull Request。

## 许可证

MIT License