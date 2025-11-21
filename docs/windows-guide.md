# Windows 安装和使用指南

## 🚀 快速开始（推荐）

### 方案一：使用 Docker（最简单，推荐）

如果您的 Windows 系统没有安装任何开发环境，推荐使用 Docker 方案：

1. **安装 Docker Desktop**
   - 访问 https://www.docker.com/products/docker-desktop/
   - 下载并安装 Docker Desktop for Windows
   - 安装完成后重启电脑

2. **运行一键安装脚本**
   ```cmd
   # 以管理员身份运行
   install-windows.bat
   # 选择 1 (Docker模式)
   ```

3. **启动应用**
   ```cmd
   docker-compose up -d
   ```

4. **访问应用**
   - 前端：http://localhost:3000
   - 后端：http://localhost:8000
   - 默认账号：admin/admin123

### 方案二：轻量级模式（无需数据库）

如果您不想安装 PostgreSQL 和 Redis，可以使用轻量级模式：

1. **安装 Node.js**
   - 访问 https://nodejs.org/
   - 下载 LTS 版本并安装

2. **运行一键安装脚本**
   ```cmd
   # 以管理员身份运行
   install-windows.bat
   # 选择 3 (轻量级模式)
   ```

3. **启动应用**
   ```cmd
   start-lite.bat dev
   ```

## 📋 前置要求

### Unity 和 Flutter 环境

无论使用哪种方案，您都需要安装：

1. **Unity Editor**
   - 下载 Unity Hub：https://unity.com/download
   - 通过 Unity Hub 安装 Unity 2022.3 LTS

2. **Flutter SDK**
   - 下载 Flutter：https://flutter.dev/docs/get-started/install/windows
   - 解压到 `C:\flutter`
   - 添加到系统 PATH

3. **Android Studio**（用于 Flutter 构建）
   - 下载：https://developer.android.com/studio
   - 安装 Android SDK

## 🛠️ 手动安装步骤

### 1. 安装基础环境

#### 使用 PowerShell 脚本（推荐）

以管理员身份打开 PowerShell：

```powershell
# 允许执行脚本
Set-ExecutionPolicy Bypass -Scope Process

# 运行安装脚本
.\start.ps1 install
```

#### 使用批处理文件

以管理员身份运行：

```cmd
start.bat install
```

### 2. 配置环境变量

编辑 `.env` 文件（如果使用轻量级模式，编辑 `.env.lite`）：

```env
# Unity 配置
UNITY_EDITOR_PATH=C:\Program Files\Unity\Hub\Editor\2022.3.10f1\Editor\Unity.exe
UNITY_REPO_PATH=C:\repos\unity_project
UNITY_REPO_URL=https://github.com/your-org/unity-project.git

# Flutter 配置
FLUTTER_SDK_PATH=C:\flutter
FLUTTER_REPO_PATH=C:\repos\flutter_project
FLUTTER_REPO_URL=https://github.com/your-org/flutter-project.git

# 数据库配置（轻量级模式使用 SQLite）
DATABASE_URL=file:./dev.db  # SQLite
# DATABASE_URL=postgresql://postgres:password@localhost:5432/flutter_unity_build  # PostgreSQL
```

### 3. 初始化数据库

```cmd
# 普通模式
start.bat init

# 轻量级模式（自动初始化）
start-lite.bat dev
```

### 4. 启动应用

#### 开发模式

```cmd
# 普通模式
start.bat dev

# 轻量级模式
start-lite.bat dev

# PowerShell
.\start.ps1 dev
```

#### 生产模式

```cmd
# 构建
start.bat build

# 启动
start.bat production
```

## 📁 目录结构说明

```
C:\flutter_build_tool\
├── frontend\           # Next.js 前端
├── backend\            # Node.js 后端
├── artifacts\          # APK 存储目录
├── logs\              # 日志文件
├── .env               # 环境配置
├── install-windows.bat # 一键安装脚本
├── start.bat          # 批处理启动脚本
└── start.ps1          # PowerShell 启动脚本
```

## 🔧 常见问题

### 1. 权限问题

**问题**：提示需要管理员权限
**解决**：右键点击脚本，选择"以管理员身份运行"

### 2. PowerShell 执行策略

**问题**：PowerShell 脚本无法执行
**解决**：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. 端口被占用

**问题**：端口 3000 或 8000 被占用
**解决**：
```cmd
# 查找占用端口的进程
netstat -ano | findstr :3000
# 结束进程
taskkill /PID [进程ID] /F
```

### 4. Node.js 版本问题

**问题**：Node.js 版本过低
**解决**：使用 nvm-windows 管理 Node 版本
```cmd
# 安装 nvm-windows
choco install nvm

# 安装并使用 Node.js 18
nvm install 18
nvm use 18
```

### 5. Redis 连接失败（非轻量级模式）

**问题**：Redis 连接失败
**解决方案**：

1. **使用 Memurai**（Windows Redis）
   - 下载：https://www.memurai.com/get-memurai
   - 安装并以服务方式运行

2. **使用 WSL**
   ```bash
   wsl --install
   wsl sudo apt update
   wsl sudo apt install redis-server
   wsl redis-server
   ```

3. **切换到轻量级模式**（推荐）
   - 无需 Redis，使用内存缓存

### 6. PostgreSQL 连接失败

**问题**：PostgreSQL 连接失败
**解决**：

1. **检查服务**
   ```cmd
   # 检查 PostgreSQL 服务
   sc query postgresql-x64-14

   # 启动服务
   net start postgresql-x64-14
   ```

2. **创建数据库**
   ```cmd
   # 使用 psql 创建数据库
   psql -U postgres
   CREATE DATABASE flutter_unity_build;
   \q
   ```

3. **或使用轻量级模式**（推荐）

### 7. Unity 构建失败

**问题**：Unity 构建脚本执行失败
**解决**：

1. 确认 Unity 路径正确
2. 检查 Unity 许可证是否激活
3. 确认项目路径存在
4. 查看日志文件：`logs\unity-build.log`

### 8. Flutter 构建失败

**问题**：Flutter APK 构建失败
**解决**：

1. 运行 Flutter 诊断
   ```cmd
   flutter doctor
   ```

2. 接受 Android 许可
   ```cmd
   flutter doctor --android-licenses
   ```

3. 确认 Android SDK 路径
   ```cmd
   echo %ANDROID_HOME%
   ```

## 🐳 Docker 部署

### 使用 Docker Compose

1. **修改 docker-compose.yml**

编辑项目路径映射：
```yaml
volumes:
  # 修改为您的实际路径
  - C:/your/unity/project:/unity_repo
  - C:/your/flutter/project:/flutter_repo
```

2. **构建和启动**

```cmd
# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 📊 性能优化

### Windows 特定优化

1. **禁用 Windows Defender 实时扫描**（对开发目录）
   - 设置 > 更新和安全 > Windows 安全 > 病毒和威胁防护 > 排除项
   - 添加项目目录

2. **使用 SSD**
   - 将项目放在 SSD 上可大幅提升构建速度

3. **增加 Node.js 内存限制**
   ```cmd
   set NODE_OPTIONS=--max-old-space-size=4096
   ```

4. **使用 pnpm 代替 npm**
   ```cmd
   npm install -g pnpm
   pnpm install
   ```

## 🚨 安全建议

1. **生产环境**
   - 修改默认密码
   - 更改 JWT_SECRET
   - 使用 HTTPS
   - 配置防火墙规则

2. **开发环境**
   - 不要将 `.env` 文件提交到版本控制
   - 定期更新依赖
   - 使用强密码

## 📝 命令参考

### 批处理命令

```cmd
start.bat install    # 安装依赖
start.bat init       # 初始化数据库
start.bat dev        # 开发模式
start.bat build      # 构建项目
start.bat production # 生产模式
start.bat migrate    # 数据库迁移
start.bat seed       # 种子数据
```

### PowerShell 命令

```powershell
.\start.ps1 install
.\start.ps1 init
.\start.ps1 dev
.\start.ps1 build
.\start.ps1 production
.\start.ps1 stop       # 停止所有服务
```

### 轻量级模式

```cmd
start-lite.bat dev    # 启动轻量级开发模式
```

## 💡 提示

1. **首次使用建议使用轻量级模式**，无需安装数据库
2. **生产环境建议使用 Docker**，更容易部署和管理
3. **开发时建议使用 PowerShell 脚本**，功能更完善
4. **遇到问题先查看日志文件**：`logs` 目录

## 📞 获取帮助

如果遇到问题：
1. 查看日志文件：`logs` 目录
2. 检查环境配置：`.env` 文件
3. 运行诊断脚本：`diagnose.bat`
4. 提交 Issue：项目 GitHub 页面