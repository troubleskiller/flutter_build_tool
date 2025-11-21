from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc
from typing import List, Optional
from datetime import datetime
import uuid
from pydantic import BaseModel
from backend.app.core.database import get_db
from backend.app.models.models import Task, TaskStatus, TaskStage, User
from backend.app.api.v1.endpoints.auth import get_current_active_user
from backend.app.services.task_manager import TaskManager
from backend.app.services.build_executor import BuildExecutor
from backend.app.core.websocket import manager as ws_manager
from loguru import logger

router = APIRouter()

# Pydantic模型
class TaskCreate(BaseModel):
    unity_branch: str
    flutter_branch: str
    unity_args: Optional[dict] = {}
    flutter_args: Optional[dict] = {}

class TaskResponse(BaseModel):
    id: int
    task_uuid: str
    status: TaskStatus
    current_stage: Optional[TaskStage]
    unity_branch: str
    flutter_branch: str
    unity_args: dict
    flutter_args: dict
    progress: int
    progress_message: Optional[str]
    created_at: datetime
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    error_message: Optional[str]
    initiator: Optional[str]

class TaskListResponse(BaseModel):
    total: int
    tasks: List[TaskResponse]

# 初始化服务
task_manager = TaskManager()
build_executor = BuildExecutor()

# API端点
@router.post("/create", response_model=TaskResponse)
async def create_task(
    task_data: TaskCreate,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """创建新的构建任务"""
    # 检查是否有正在运行的任务（全局互斥锁）
    if await task_manager.has_running_task(db):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Another task is currently running. Please wait or cancel it first."
        )

    # 创建任务
    task_uuid = str(uuid.uuid4())
    new_task = Task(
        task_uuid=task_uuid,
        status=TaskStatus.QUEUED,
        initiator_id=current_user.id,
        unity_branch=task_data.unity_branch,
        flutter_branch=task_data.flutter_branch,
        unity_args=task_data.unity_args,
        flutter_args=task_data.flutter_args,
        progress=0,
        progress_message="Task queued"
    )

    db.add(new_task)
    await db.commit()
    await db.refresh(new_task)

    # 发送WebSocket通知
    await ws_manager.send_task_update(
        task_uuid,
        "created",
        {
            "id": new_task.id,
            "status": new_task.status.value,
            "message": "Task created and queued"
        }
    )

    # 异步启动任务执行
    await build_executor.execute_task(new_task.id)

    logger.info(f"Task created: {task_uuid} by user {current_user.username}")

    return TaskResponse(
        id=new_task.id,
        task_uuid=new_task.task_uuid,
        status=new_task.status,
        current_stage=new_task.current_stage,
        unity_branch=new_task.unity_branch,
        flutter_branch=new_task.flutter_branch,
        unity_args=new_task.unity_args,
        flutter_args=new_task.flutter_args,
        progress=new_task.progress,
        progress_message=new_task.progress_message,
        created_at=new_task.created_at,
        started_at=new_task.started_at,
        completed_at=new_task.completed_at,
        error_message=new_task.error_message,
        initiator=current_user.username
    )

@router.get("/current", response_model=Optional[TaskResponse])
async def get_current_task(
    db: AsyncSession = Depends(get_db)
):
    """获取当前正在运行的任务"""
    result = await db.execute(
        select(Task).where(
            Task.status.in_([TaskStatus.RUNNING, TaskStatus.QUEUED])
        ).order_by(Task.created_at.desc())
    )
    task = result.scalar_one_or_none()

    if not task:
        return None

    # 获取用户信息
    initiator_name = None
    if task.initiator_id:
        user_result = await db.execute(
            select(User).where(User.id == task.initiator_id)
        )
        user = user_result.scalar_one_or_none()
        if user:
            initiator_name = user.username

    return TaskResponse(
        id=task.id,
        task_uuid=task.task_uuid,
        status=task.status,
        current_stage=task.current_stage,
        unity_branch=task.unity_branch,
        flutter_branch=task.flutter_branch,
        unity_args=task.unity_args or {},
        flutter_args=task.flutter_args or {},
        progress=task.progress,
        progress_message=task.progress_message,
        created_at=task.created_at,
        started_at=task.started_at,
        completed_at=task.completed_at,
        error_message=task.error_message,
        initiator=initiator_name
    )

@router.get("/list", response_model=TaskListResponse)
async def list_tasks(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    status: Optional[TaskStatus] = None,
    user_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db)
):
    """获取任务列表"""
    # 构建查询条件
    conditions = []
    if status:
        conditions.append(Task.status == status)
    if user_id:
        conditions.append(Task.initiator_id == user_id)

    # 查询总数
    count_query = select(Task)
    if conditions:
        count_query = count_query.where(and_(*conditions))

    count_result = await db.execute(count_query)
    total = len(count_result.all())

    # 查询任务列表
    query = select(Task)
    if conditions:
        query = query.where(and_(*conditions))
    query = query.order_by(desc(Task.created_at)).offset(skip).limit(limit)

    result = await db.execute(query)
    tasks = result.scalars().all()

    # 构建响应
    task_responses = []
    for task in tasks:
        # 获取用户信息
        initiator_name = None
        if task.initiator_id:
            user_result = await db.execute(
                select(User).where(User.id == task.initiator_id)
            )
            user = user_result.scalar_one_or_none()
            if user:
                initiator_name = user.username

        task_responses.append(TaskResponse(
            id=task.id,
            task_uuid=task.task_uuid,
            status=task.status,
            current_stage=task.current_stage,
            unity_branch=task.unity_branch,
            flutter_branch=task.flutter_branch,
            unity_args=task.unity_args or {},
            flutter_args=task.flutter_args or {},
            progress=task.progress,
            progress_message=task.progress_message,
            created_at=task.created_at,
            started_at=task.started_at,
            completed_at=task.completed_at,
            error_message=task.error_message,
            initiator=initiator_name
        ))

    return TaskListResponse(total=total, tasks=task_responses)

@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: int,
    db: AsyncSession = Depends(get_db)
):
    """获取特定任务详情"""
    result = await db.execute(
        select(Task).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()

    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )

    # 获取用户信息
    initiator_name = None
    if task.initiator_id:
        user_result = await db.execute(
            select(User).where(User.id == task.initiator_id)
        )
        user = user_result.scalar_one_or_none()
        if user:
            initiator_name = user.username

    return TaskResponse(
        id=task.id,
        task_uuid=task.task_uuid,
        status=task.status,
        current_stage=task.current_stage,
        unity_branch=task.unity_branch,
        flutter_branch=task.flutter_branch,
        unity_args=task.unity_args or {},
        flutter_args=task.flutter_args or {},
        progress=task.progress,
        progress_message=task.progress_message,
        created_at=task.created_at,
        started_at=task.started_at,
        completed_at=task.completed_at,
        error_message=task.error_message,
        initiator=initiator_name
    )

@router.post("/{task_id}/cancel")
async def cancel_task(
    task_id: int,
    current_user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """取消任务"""
    result = await db.execute(
        select(Task).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()

    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )

    if task.status not in [TaskStatus.PENDING, TaskStatus.QUEUED, TaskStatus.RUNNING]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Task cannot be cancelled in current status"
        )

    # 取消任务
    await task_manager.cancel_task(task_id, db)

    # 发送WebSocket通知
    await ws_manager.send_task_update(
        task.task_uuid,
        "cancelled",
        {"message": f"Task cancelled by {current_user.username}"}
    )

    logger.info(f"Task {task_id} cancelled by user {current_user.username}")
    return {"message": "Task cancelled successfully"}

@router.get("/{task_id}/logs")
async def get_task_logs(
    task_id: int,
    stage: Optional[TaskStage] = None,
    db: AsyncSession = Depends(get_db)
):
    """获取任务日志"""
    # 这里简化实现，实际应该从日志文件或数据库读取
    result = await db.execute(
        select(Task).where(Task.id == task_id)
    )
    task = result.scalar_one_or_none()

    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found"
        )

    # TODO: 实现日志读取逻辑
    logs = {
        "task_id": task_id,
        "logs": "Sample log content here...",
        "stage": stage
    }

    return logs