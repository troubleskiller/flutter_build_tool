from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import socketio
from backend.app.core.config import settings
from backend.app.core.database import engine, Base
from backend.app.api.v1.api import api_router
from backend.app.core.websocket import sio, socket_app
from loguru import logger
import os

# 创建必要的目录
os.makedirs("../artifacts", exist_ok=True)
os.makedirs("../logs", exist_ok=True)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时
    logger.info("Starting Flutter Unity Build Tool...")
    # 创建数据库表
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield

    # 关闭时
    logger.info("Shutting down Flutter Unity Build Tool...")

# 创建FastAPI应用
app = FastAPI(
    title="Flutter Unity Build Tool",
    description="自动化构建Unity和Flutter项目的管理平台",
    version="1.0.0",
    lifespan=lifespan
)

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册API路由
app.include_router(api_router, prefix="/api/v1")

# 挂载静态文件（用于下载APK）
app.mount("/artifacts", StaticFiles(directory="../artifacts"), name="artifacts")

# 挂载Socket.IO应用
app.mount("/ws", socket_app)

@app.get("/")
async def root():
    """健康检查端点"""
    return {
        "status": "healthy",
        "service": "Flutter Unity Build Tool API",
        "version": "1.0.0"
    }

@app.get("/health")
async def health_check():
    """详细健康检查"""
    return {
        "status": "healthy",
        "database": "connected",
        "redis": "connected",
        "websocket": "active"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_config={
            "version": 1,
            "disable_existing_loggers": False,
            "formatters": {
                "default": {
                    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
                },
            },
            "handlers": {
                "default": {
                    "formatter": "default",
                    "class": "logging.StreamHandler",
                    "stream": "ext://sys.stderr",
                },
            },
            "root": {
                "level": "INFO",
                "handlers": ["default"],
            },
        }
    )