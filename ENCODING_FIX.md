# Windows命令行中文乱码解决方案

## 问题原因
Windows命令行默认使用GBK编码（代码页936），而批处理文件可能使用UTF-8编码，导致中文显示乱码。

## 已实施的解决方案

### 1. 添加UTF-8编码设置
在所有批处理文件开头添加了：
```batch
chcp 65001 >nul 2>&1
```
这会将命令行编码切换到UTF-8（代码页65001）。

### 2. 改为英文版本
主要的Docker管理脚本已改为英文版本，避免中文显示问题：
- `docker-quickstart.bat` - 完全英文版
- `docker-start.bat` - 完全英文版

### 3. 已修改的文件
以下文件都添加了UTF-8编码设置：
- ✅ `docker-quickstart.bat`
- ✅ `docker-start.bat`
- ✅ `start.bat`
- ✅ `backend/src/scripts/flutter-build.bat`
- ✅ `backend/src/scripts/unity-build.bat`

## 测试编码
运行以下命令测试编码是否正常：
```batch
test-encoding.bat
```

## 其他解决方案

### 方案1：修改Windows终端设置
1. 打开Windows Terminal或CMD
2. 右键标题栏 -> 属性
3. 在"选项"标签中，将"代码页"改为"65001 (UTF-8)"

### 方案2：永久设置UTF-8
在系统环境变量中添加：
```
变量名：LANG
变量值：zh_CN.UTF-8
```

### 方案3：使用Windows Terminal
推荐安装Windows Terminal（从Microsoft Store下载），它默认支持UTF-8。

### 方案4：使用PowerShell脚本
PowerShell默认支持UTF-8，可以使用 `docker-start.ps1` 替代批处理文件。

## 使用建议

1. **推荐使用英文版脚本**
   - `docker-quickstart.bat` - 一键启动
   - `docker-start.bat` - 完整管理功能

2. **如果仍有乱码**
   - 确保命令行窗口使用支持UTF-8的字体（如Consolas）
   - 使用Windows Terminal代替传统CMD
   - 使用PowerShell版本的脚本

3. **Docker命令直接使用**
   如果脚本有问题，可以直接使用Docker命令：
   ```batch
   # 启动所有服务
   docker-compose up -d

   # 停止所有服务
   docker-compose down

   # 查看日志
   docker-compose logs -f
   ```

## 总结
- 所有批处理文件已添加UTF-8编码支持
- 主要脚本已改为英文版本
- 提供了多种备选解决方案
- 可以使用test-encoding.bat测试编码设置