# Flutter + Unity 打包工具

## 项目简介
这是一个用于自动化构建 Unity 和 Flutter 项目的 Web 工具，提供了完整的任务管理、实时日志、产物下载等功能。

## 技术栈
- **前端**: Next.js 14, TypeScript, Tailwind CSS, shadcn/ui
- **后端**: Python 3.9+, FastAPI, SQLAlchemy, Celery
- **数据库**: PostgreSQL
- **缓存**: Redis
- **实时通信**: WebSocket
- **脚本执行**: Shell scripts

## 项目结构
```
flutter_build_tool/
├── frontend/               # Next.js 前端应用
│   ├── src/
│   │   ├── components/    # React 组件
│   │   ├── pages/         # 页面路由
│   │   ├── services/      # API 服务
│   │   ├── utils/         # 工具函数
│   │   └── styles/        # 样式文件
│   ├── public/            # 静态资源
│   └── package.json
│
├── backend/               # Python FastAPI 后端
│   ├── app/
│   │   ├── api/          # API 路由端点
│   │   ├── core/         # 核心配置和依赖
│   │   ├── models/       # 数据库模型
│   │   ├── services/     # 业务逻辑服务
│   │   └── utils/        # 工具函数
│   ├── scripts/          # Shell 脚本
│   ├── config/           # 配置文件
│   └── requirements.txt
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
   - 实时日志流式传输
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
- Python 3.9+
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

2. 安装后端依赖
```bash
cd backend
pip install -r requirements.txt
```

3. 安装前端依赖
```bash
cd frontend
npm install
```

4. 配置环境变量
```bash
cp .env.example .env
# 编辑 .env 文件配置数据库、Redis 等连接信息
```

5. 初始化数据库
```bash
cd backend
python scripts/init_db.py
```

6. 启动服务
```bash
# 启动后端
cd backend
uvicorn app.main:app --reload

# 启动前端
cd frontend
npm run dev
```

访问 http://localhost:3000 即可使用系统。

## API 文档
后端 API 文档可通过 http://localhost:8000/docs 访问。

## 贡献指南
欢迎提交 Issue 和 Pull Request。

## 许可证
MIT License