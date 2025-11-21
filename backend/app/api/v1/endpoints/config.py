from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
from pydantic import BaseModel
from app.core.database import get_db
from app.models.models import RepoConfig, CleanupPolicy
from app.api.v1.endpoints.auth import get_admin_user
from datetime import datetime
from loguru import logger
import git

router = APIRouter()

# Pydantic模型
class RepoConfigCreate(BaseModel):
    repo_type: str  # "unity" or "flutter"
    repo_url: str
    repo_path: str
    default_branch: str = "main"
    auth_type: str = "https"
    auth_credentials: str = ""
    use_mirror: bool = False
    mirror_url: str = ""

class RepoConfigResponse(BaseModel):
    id: int
    repo_type: str
    repo_url: str
    repo_path: str
    default_branch: str
    use_mirror: bool
    mirror_url: str
    updated_at: datetime

class CleanupPolicyCreate(BaseModel):
    policy_name: str
    retention_days: int = 30
    retention_count: int = 100
    clean_failed_tasks: bool = False
    archive_before_delete: bool = True
    archive_path: str = ""
    schedule_cron: str = ""

class CleanupPolicyResponse(BaseModel):
    id: int
    policy_name: str
    is_active: bool
    retention_days: int
    retention_count: int
    clean_failed_tasks: bool
    archive_before_delete: bool
    archive_path: str
    schedule_cron: str
    last_run_at: datetime = None
    next_run_at: datetime = None

class BranchInfo(BaseModel):
    name: str
    last_commit: str
    last_commit_message: str
    last_commit_date: str

# API端点 - 仓库配置
@router.get("/repos", response_model=List[RepoConfigResponse])
async def list_repo_configs(
    db: AsyncSession = Depends(get_db)
):
    """获取仓库配置列表"""
    result = await db.execute(select(RepoConfig))
    configs = result.scalars().all()

    return [RepoConfigResponse(
        id=config.id,
        repo_type=config.repo_type,
        repo_url=config.repo_url,
        repo_path=config.repo_path,
        default_branch=config.default_branch,
        use_mirror=config.use_mirror,
        mirror_url=config.mirror_url or "",
        updated_at=config.updated_at
    ) for config in configs]

@router.post("/repos", response_model=RepoConfigResponse)
async def create_repo_config(
    config_data: RepoConfigCreate,
    current_user = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db)
):
    """创建或更新仓库配置（管理员权限）"""
    # 检查是否已存在
    result = await db.execute(
        select(RepoConfig).where(RepoConfig.repo_type == config_data.repo_type)
    )
    existing_config = result.scalar_one_or_none()

    if existing_config:
        # 更新现有配置
        for key, value in config_data.dict().items():
            setattr(existing_config, key, value)
        existing_config.updated_at = datetime.utcnow()
        config = existing_config
    else:
        # 创建新配置
        config = RepoConfig(**config_data.dict())
        db.add(config)

    await db.commit()
    await db.refresh(config)

    logger.info(f"Repo config for {config_data.repo_type} updated by {current_user.username}")

    return RepoConfigResponse(
        id=config.id,
        repo_type=config.repo_type,
        repo_url=config.repo_url,
        repo_path=config.repo_path,
        default_branch=config.default_branch,
        use_mirror=config.use_mirror,
        mirror_url=config.mirror_url or "",
        updated_at=config.updated_at
    )

@router.get("/repos/{repo_type}/branches")
async def get_repo_branches(
    repo_type: str,
    db: AsyncSession = Depends(get_db)
):
    """获取仓库分支列表"""
    # 获取仓库配置
    result = await db.execute(
        select(RepoConfig).where(RepoConfig.repo_type == repo_type)
    )
    config = result.scalar_one_or_none()

    if not config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Repository configuration for {repo_type} not found"
        )

    try:
        # 克隆或打开仓库
        repo = git.Repo(config.repo_path)

        # 获取远程分支
        branches = []
        for ref in repo.remote().refs:
            if not ref.name.endswith('/HEAD'):
                branch_name = ref.name.split('/')[-1]
                try:
                    commit = ref.commit
                    branches.append(BranchInfo(
                        name=branch_name,
                        last_commit=commit.hexsha[:8],
                        last_commit_message=commit.message.split('\n')[0],
                        last_commit_date=commit.committed_datetime.isoformat()
                    ))
                except:
                    pass

        return branches
    except Exception as e:
        logger.error(f"Failed to get branches for {repo_type}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get branches: {str(e)}"
        )

# API端点 - 清理策略
@router.get("/cleanup-policies", response_model=List[CleanupPolicyResponse])
async def list_cleanup_policies(
    db: AsyncSession = Depends(get_db)
):
    """获取清理策略列表"""
    result = await db.execute(select(CleanupPolicy))
    policies = result.scalars().all()

    return [CleanupPolicyResponse(
        id=policy.id,
        policy_name=policy.policy_name,
        is_active=policy.is_active,
        retention_days=policy.retention_days,
        retention_count=policy.retention_count,
        clean_failed_tasks=policy.clean_failed_tasks,
        archive_before_delete=policy.archive_before_delete,
        archive_path=policy.archive_path or "",
        schedule_cron=policy.schedule_cron or "",
        last_run_at=policy.last_run_at,
        next_run_at=policy.next_run_at
    ) for policy in policies]

@router.post("/cleanup-policies", response_model=CleanupPolicyResponse)
async def create_cleanup_policy(
    policy_data: CleanupPolicyCreate,
    current_user = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db)
):
    """创建清理策略（管理员权限）"""
    # 检查是否已存在同名策略
    result = await db.execute(
        select(CleanupPolicy).where(CleanupPolicy.policy_name == policy_data.policy_name)
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Policy with this name already exists"
        )

    policy = CleanupPolicy(**policy_data.dict())
    db.add(policy)
    await db.commit()
    await db.refresh(policy)

    logger.info(f"Cleanup policy '{policy_data.policy_name}' created by {current_user.username}")

    return CleanupPolicyResponse(
        id=policy.id,
        policy_name=policy.policy_name,
        is_active=policy.is_active,
        retention_days=policy.retention_days,
        retention_count=policy.retention_count,
        clean_failed_tasks=policy.clean_failed_tasks,
        archive_before_delete=policy.archive_before_delete,
        archive_path=policy.archive_path or "",
        schedule_cron=policy.schedule_cron or "",
        last_run_at=policy.last_run_at,
        next_run_at=policy.next_run_at
    )

@router.put("/cleanup-policies/{policy_id}/toggle")
async def toggle_cleanup_policy(
    policy_id: int,
    current_user = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db)
):
    """启用/禁用清理策略（管理员权限）"""
    result = await db.execute(
        select(CleanupPolicy).where(CleanupPolicy.id == policy_id)
    )
    policy = result.scalar_one_or_none()

    if not policy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Policy not found"
        )

    policy.is_active = not policy.is_active
    policy.updated_at = datetime.utcnow()
    await db.commit()

    action = "activated" if policy.is_active else "deactivated"
    logger.info(f"Cleanup policy {policy_id} {action} by {current_user.username}")

    return {"message": f"Policy {action} successfully", "is_active": policy.is_active}