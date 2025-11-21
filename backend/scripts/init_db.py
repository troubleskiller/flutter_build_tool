#!/usr/bin/env python3
"""
数据库初始化脚本
"""
import asyncio
import sys
from pathlib import Path

# 添加项目路径到系统路径
sys.path.append(str(Path(__file__).parent.parent.parent))

from sqlalchemy.ext.asyncio import create_async_engine
from app.core.config import settings
from app.core.database import Base
from app.models.models import *  # 导入所有模型
from loguru import logger

async def init_database():
    """初始化数据库"""
    logger.info("Starting database initialization...")

    # 创建数据库引擎
    engine = create_async_engine(
        settings.DATABASE_URL,
        echo=True,
    )

    try:
        # 创建所有表
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.drop_all)
            await conn.run_sync(Base.metadata.create_all)

        logger.info("Database tables created successfully")

        # 创建默认管理员用户
        from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
        from app.api.v1.endpoints.auth import get_password_hash

        AsyncSessionLocal = async_sessionmaker(
            engine,
            class_=AsyncSession,
            expire_on_commit=False
        )

        async with AsyncSessionLocal() as db:
            # 创建admin用户
            admin_user = User(
                username="admin",
                email="admin@example.com",
                hashed_password=get_password_hash("admin123"),
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin_user)

            # 创建测试用户
            test_user = User(
                username="test",
                email="test@example.com",
                hashed_password=get_password_hash("test123"),
                role=UserRole.USER,
                is_active=True
            )
            db.add(test_user)

            # 创建默认清理策略
            default_policy = CleanupPolicy(
                policy_name="default",
                retention_days=30,
                retention_count=100,
                clean_failed_tasks=False,
                archive_before_delete=True,
                is_active=True
            )
            db.add(default_policy)

            await db.commit()
            logger.info("Default data created successfully")

    except Exception as e:
        logger.error(f"Database initialization failed: {str(e)}")
        raise
    finally:
        await engine.dispose()

if __name__ == "__main__":
    logger.info("Database initialization script")
    logger.info(f"Using database: {settings.DATABASE_URL}")

    # 运行初始化
    asyncio.run(init_database())

    logger.info("Database initialization completed!")