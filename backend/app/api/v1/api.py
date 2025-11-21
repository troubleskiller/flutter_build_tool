from fastapi import APIRouter
from app.api.v1.endpoints import auth, tasks, artifacts, statistics, config

api_router = APIRouter()

# 注册各个端点
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
api_router.include_router(artifacts.router, prefix="/artifacts", tags=["artifacts"])
api_router.include_router(statistics.router, prefix="/statistics", tags=["statistics"])
api_router.include_router(config.router, prefix="/config", tags=["configuration"])