from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from typing import Optional
from datetime import datetime, timedelta
from pydantic import BaseModel
from app.core.database import get_db
from app.models.models import Task, TaskStatus, Statistics
from loguru import logger

router = APIRouter()

# Pydantic模型
class StatisticsSummary(BaseModel):
    total_tasks: int
    success_count: int
    failed_count: int
    success_rate: float
    avg_duration: float
    today_builds: int
    this_week_builds: int
    this_month_builds: int

class BranchStatistics(BaseModel):
    branch_name: str
    task_count: int
    success_rate: float
    avg_duration: float

class TimeSeriesData(BaseModel):
    date: str
    task_count: int
    success_count: int
    failed_count: int

# API端点
@router.get("/summary", response_model=StatisticsSummary)
async def get_statistics_summary(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db)
):
    """获取统计摘要"""
    # 计算日期范围
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    today_start = end_date.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = end_date - timedelta(days=end_date.weekday())
    month_start = end_date.replace(day=1)

    # 查询总任务数
    total_result = await db.execute(
        select(func.count(Task.id)).where(
            Task.created_at >= start_date
        )
    )
    total_tasks = total_result.scalar() or 0

    # 查询成功和失败的任务数
    success_result = await db.execute(
        select(func.count(Task.id)).where(
            and_(
                Task.created_at >= start_date,
                Task.status == TaskStatus.SUCCESS
            )
        )
    )
    success_count = success_result.scalar() or 0

    failed_result = await db.execute(
        select(func.count(Task.id)).where(
            and_(
                Task.created_at >= start_date,
                Task.status == TaskStatus.FAILED
            )
        )
    )
    failed_count = failed_result.scalar() or 0

    # 计算成功率
    success_rate = (success_count / total_tasks * 100) if total_tasks > 0 else 0

    # 计算平均耗时
    avg_duration_result = await db.execute(
        select(func.avg(Task.total_duration)).where(
            and_(
                Task.created_at >= start_date,
                Task.status == TaskStatus.SUCCESS,
                Task.total_duration.isnot(None)
            )
        )
    )
    avg_duration = avg_duration_result.scalar() or 0

    # 今日构建数
    today_result = await db.execute(
        select(func.count(Task.id)).where(
            Task.created_at >= today_start
        )
    )
    today_builds = today_result.scalar() or 0

    # 本周构建数
    week_result = await db.execute(
        select(func.count(Task.id)).where(
            Task.created_at >= week_start
        )
    )
    this_week_builds = week_result.scalar() or 0

    # 本月构建数
    month_result = await db.execute(
        select(func.count(Task.id)).where(
            Task.created_at >= month_start
        )
    )
    this_month_builds = month_result.scalar() or 0

    return StatisticsSummary(
        total_tasks=total_tasks,
        success_count=success_count,
        failed_count=failed_count,
        success_rate=round(success_rate, 2),
        avg_duration=round(avg_duration / 60, 2) if avg_duration else 0,  # 转换为分钟
        today_builds=today_builds,
        this_week_builds=this_week_builds,
        this_month_builds=this_month_builds
    )

@router.get("/by-branch")
async def get_branch_statistics(
    branch_type: str = Query("unity", regex="^(unity|flutter)$"),
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db)
):
    """按分支统计"""
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)

    # 根据分支类型选择字段
    branch_field = Task.unity_branch if branch_type == "unity" else Task.flutter_branch

    # 查询分支统计
    result = await db.execute(
        select(
            branch_field.label("branch"),
            func.count(Task.id).label("task_count"),
            func.count(Task.id).filter(Task.status == TaskStatus.SUCCESS).label("success_count"),
            func.avg(Task.total_duration).label("avg_duration")
        ).where(
            Task.created_at >= start_date
        ).group_by(branch_field)
    )

    statistics = []
    for row in result:
        task_count = row.task_count or 0
        success_count = row.success_count or 0
        success_rate = (success_count / task_count * 100) if task_count > 0 else 0

        statistics.append(BranchStatistics(
            branch_name=row.branch,
            task_count=task_count,
            success_rate=round(success_rate, 2),
            avg_duration=round(row.avg_duration / 60, 2) if row.avg_duration else 0
        ))

    return statistics

@router.get("/time-series")
async def get_time_series_statistics(
    days: int = Query(7, ge=1, le=30),
    db: AsyncSession = Depends(get_db)
):
    """获取时间序列统计数据"""
    end_date = datetime.utcnow().date()
    start_date = end_date - timedelta(days=days)

    # 查询每日统计
    result = await db.execute(
        select(
            func.date(Task.created_at).label("date"),
            func.count(Task.id).label("task_count"),
            func.count(Task.id).filter(Task.status == TaskStatus.SUCCESS).label("success_count"),
            func.count(Task.id).filter(Task.status == TaskStatus.FAILED).label("failed_count")
        ).where(
            Task.created_at >= start_date
        ).group_by(func.date(Task.created_at))
    )

    data = []
    for row in result:
        data.append(TimeSeriesData(
            date=str(row.date),
            task_count=row.task_count or 0,
            success_count=row.success_count or 0,
            failed_count=row.failed_count or 0
        ))

    return data

@router.get("/top-users")
async def get_top_users(
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db)
):
    """获取活跃用户排行"""
    from app.models.models import User

    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)

    result = await db.execute(
        select(
            User.username,
            func.count(Task.id).label("task_count"),
            func.count(Task.id).filter(Task.status == TaskStatus.SUCCESS).label("success_count")
        ).join(
            Task, Task.initiator_id == User.id
        ).where(
            Task.created_at >= start_date
        ).group_by(User.username).order_by(func.count(Task.id).desc()).limit(limit)
    )

    users = []
    for row in result:
        task_count = row.task_count or 0
        success_count = row.success_count or 0
        success_rate = (success_count / task_count * 100) if task_count > 0 else 0

        users.append({
            "username": row.username,
            "task_count": task_count,
            "success_count": success_count,
            "success_rate": round(success_rate, 2)
        })

    return users