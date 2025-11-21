from typing import List, Optional, Union
from pydantic_settings import BaseSettings
from pydantic import AnyHttpUrl, validator
import os
from pathlib import Path

class Settings(BaseSettings):
    # 基础配置
    PROJECT_NAME: str = "Flutter Unity Build Tool"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    # 安全配置
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-here-change-in-production")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # 数据库配置
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://postgres:password@localhost:5432/flutter_unity_build"
    )

    # Redis配置
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")

    # CORS配置
    BACKEND_CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8000",
    ]

    # Unity和Flutter配置
    UNITY_EDITOR_PATH: str = os.getenv(
        "UNITY_EDITOR_PATH",
        "/Applications/Unity/Hub/Editor/2022.3.10f1/Unity.app/Contents/MacOS/Unity"
    )
    FLUTTER_SDK_PATH: str = os.getenv("FLUTTER_SDK_PATH", "/usr/local/flutter")

    # Git仓库配置
    UNITY_REPO_PATH: str = os.getenv("UNITY_REPO_PATH", "/tmp/unity_repo")
    FLUTTER_REPO_PATH: str = os.getenv("FLUTTER_REPO_PATH", "/tmp/flutter_repo")
    UNITY_REPO_URL: str = os.getenv("UNITY_REPO_URL", "")
    FLUTTER_REPO_URL: str = os.getenv("FLUTTER_REPO_URL", "")

    # 构建配置
    BUILD_TIMEOUT: int = 3600  # 1小时
    MAX_CONCURRENT_BUILDS: int = 1  # 全局互斥锁，只允许一个构建

    # 产物管理
    ARTIFACTS_DIR: Path = Path("../artifacts")
    LOGS_DIR: Path = Path("../logs")
    MAX_ARTIFACT_AGE_DAYS: int = 30
    MAX_ARTIFACT_COUNT: int = 100

    # 日志配置
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

    # Celery配置
    CELERY_BROKER_URL: str = os.getenv("CELERY_BROKER_URL", "redis://localhost:6379/0")
    CELERY_RESULT_BACKEND: str = os.getenv("CELERY_RESULT_BACKEND", "redis://localhost:6379/0")

    # 邮件配置（可选）
    SMTP_HOST: Optional[str] = os.getenv("SMTP_HOST", None)
    SMTP_PORT: Optional[int] = int(os.getenv("SMTP_PORT", 587)) if os.getenv("SMTP_PORT") else None
    SMTP_USER: Optional[str] = os.getenv("SMTP_USER", None)
    SMTP_PASSWORD: Optional[str] = os.getenv("SMTP_PASSWORD", None)

    # Webhook配置（可选）
    WEBHOOK_URL: Optional[str] = os.getenv("WEBHOOK_URL", None)

    class Config:
        env_file = ".env"
        case_sensitive = True

    @validator("BACKEND_CORS_ORIGINS", pre=True)
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> Union[List[str], str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)

settings = Settings()