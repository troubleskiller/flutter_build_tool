from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel
from app.core.database import get_db
from app.models.models import Artifact, Task
from app.api.v1.endpoints.auth import get_current_active_user
from pathlib import Path
from loguru import logger

router = APIRouter()

# Pydantic模型
class ArtifactResponse(BaseModel):
    id: int
    task_id: int
    file_name: str
    file_size: int
    download_url: str
    created_at: datetime
    download_count: int
    is_archived: bool
    task_info: dict

class ArtifactListResponse(BaseModel):
    total: int
    artifacts: List[ArtifactResponse]

# API端点
@router.get("/list", response_model=ArtifactListResponse)
async def list_artifacts(
    skip: int = 0,
    limit: int = 20,
    is_archived: Optional[bool] = False,
    db: AsyncSession = Depends(get_db)
):
    """获取产物列表"""
    # 查询总数
    count_query = select(Artifact).where(Artifact.is_archived == is_archived)
    count_result = await db.execute(count_query)
    total = len(count_result.all())

    # 查询产物列表
    query = select(Artifact).where(
        Artifact.is_archived == is_archived
    ).order_by(desc(Artifact.created_at)).offset(skip).limit(limit)

    result = await db.execute(query)
    artifacts = result.scalars().all()

    # 构建响应
    artifact_responses = []
    for artifact in artifacts:
        # 获取关联的任务信息
        task_result = await db.execute(
            select(Task).where(Task.id == artifact.task_id)
        )
        task = task_result.scalar_one_or_none()

        task_info = {}
        if task:
            task_info = {
                "task_uuid": task.task_uuid,
                "unity_branch": task.unity_branch,
                "flutter_branch": task.flutter_branch,
                "status": task.status.value
            }

        artifact_responses.append(ArtifactResponse(
            id=artifact.id,
            task_id=artifact.task_id,
            file_name=artifact.file_name,
            file_size=artifact.file_size,
            download_url=artifact.download_url,
            created_at=artifact.created_at,
            download_count=artifact.download_count,
            is_archived=artifact.is_archived,
            task_info=task_info
        ))

    return ArtifactListResponse(total=total, artifacts=artifact_responses)

@router.get("/{artifact_id}", response_model=ArtifactResponse)
async def get_artifact(
    artifact_id: int,
    db: AsyncSession = Depends(get_db)
):
    """获取产物详情"""
    result = await db.execute(
        select(Artifact).where(Artifact.id == artifact_id)
    )
    artifact = result.scalar_one_or_none()

    if not artifact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Artifact not found"
        )

    # 获取关联的任务信息
    task_result = await db.execute(
        select(Task).where(Task.id == artifact.task_id)
    )
    task = task_result.scalar_one_or_none()

    task_info = {}
    if task:
        task_info = {
            "task_uuid": task.task_uuid,
            "unity_branch": task.unity_branch,
            "flutter_branch": task.flutter_branch,
            "status": task.status.value
        }

    return ArtifactResponse(
        id=artifact.id,
        task_id=artifact.task_id,
        file_name=artifact.file_name,
        file_size=artifact.file_size,
        download_url=artifact.download_url,
        created_at=artifact.created_at,
        download_count=artifact.download_count,
        is_archived=artifact.is_archived,
        task_info=task_info
    )

@router.get("/{artifact_id}/download")
async def download_artifact(
    artifact_id: int,
    db: AsyncSession = Depends(get_db)
):
    """下载产物文件"""
    result = await db.execute(
        select(Artifact).where(Artifact.id == artifact_id)
    )
    artifact = result.scalar_one_or_none()

    if not artifact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Artifact not found"
        )

    # 检查文件是否存在
    file_path = Path(artifact.file_path)
    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Artifact file not found on disk"
        )

    # 更新下载计数
    artifact.download_count += 1
    artifact.last_downloaded_at = datetime.utcnow()
    await db.commit()

    logger.info(f"Artifact {artifact_id} downloaded")

    return FileResponse(
        path=str(file_path),
        filename=artifact.file_name,
        media_type='application/vnd.android.package-archive'
    )

@router.delete("/{artifact_id}")
async def delete_artifact(
    artifact_id: int,
    current_user = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """删除产物（需要管理员权限）"""
    # 检查权限
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can delete artifacts"
        )

    result = await db.execute(
        select(Artifact).where(Artifact.id == artifact_id)
    )
    artifact = result.scalar_one_or_none()

    if not artifact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Artifact not found"
        )

    # 删除文件
    file_path = Path(artifact.file_path)
    if file_path.exists():
        file_path.unlink()

    # 删除数据库记录
    await db.delete(artifact)
    await db.commit()

    logger.info(f"Artifact {artifact_id} deleted by {current_user.username}")
    return {"message": "Artifact deleted successfully"}

@router.post("/{artifact_id}/archive")
async def archive_artifact(
    artifact_id: int,
    current_user = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """归档产物"""
    result = await db.execute(
        select(Artifact).where(Artifact.id == artifact_id)
    )
    artifact = result.scalar_one_or_none()

    if not artifact:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Artifact not found"
        )

    if artifact.is_archived:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Artifact is already archived"
        )

    # 归档产物
    artifact.is_archived = True
    artifact.archived_at = datetime.utcnow()
    await db.commit()

    logger.info(f"Artifact {artifact_id} archived by {current_user.username}")
    return {"message": "Artifact archived successfully"}