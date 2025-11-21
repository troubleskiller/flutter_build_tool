import asyncio
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from backend.app.models.models import Task, TaskStatus, TaskStage
from datetime import datetime
from loguru import logger
import redis.asyncio as redis
from backend.app.core.config import settings

class TaskManager:
    """任务管理器，负责全局互斥锁和任务队列管理"""

    def __init__(self):
        self.redis_client = None
        self.lock_key = "build_task_lock"
        self.queue_key = "build_task_queue"
        self.lock_timeout = 3600  # 1小时超时

    async def _get_redis(self):
        """获取Redis连接"""
        if not self.redis_client:
            self.redis_client = await redis.from_url(settings.REDIS_URL)
        return self.redis_client

    async def acquire_lock(self, task_id: int) -> bool:
        """尝试获取全局锁"""
        redis_client = await self._get_redis()

        # 使用SET NX EX实现分布式锁
        result = await redis_client.set(
            self.lock_key,
            str(task_id),
            ex=self.lock_timeout,
            nx=True
        )

        if result:
            logger.info(f"Task {task_id} acquired global lock")
            return True
        else:
            logger.warning(f"Task {task_id} failed to acquire lock")
            return False

    async def release_lock(self, task_id: int) -> bool:
        """释放全局锁"""
        redis_client = await self._get_redis()

        # 只有持有锁的任务才能释放锁
        current_lock = await redis_client.get(self.lock_key)
        if current_lock and int(current_lock) == task_id:
            await redis_client.delete(self.lock_key)
            logger.info(f"Task {task_id} released global lock")
            return True
        else:
            logger.warning(f"Task {task_id} cannot release lock (not owner)")
            return False

    async def has_running_task(self, db: AsyncSession) -> bool:
        """检查是否有正在运行的任务"""
        result = await db.execute(
            select(Task).where(
                Task.status.in_([TaskStatus.RUNNING, TaskStatus.QUEUED])
            )
        )
        return result.scalar_one_or_none() is not None

    async def get_current_task(self, db: AsyncSession) -> Optional[Task]:
        """获取当前正在运行的任务"""
        result = await db.execute(
            select(Task).where(Task.status == TaskStatus.RUNNING)
        )
        return result.scalar_one_or_none()

    async def enqueue_task(self, task_id: int) -> bool:
        """将任务加入队列"""
        redis_client = await self._get_redis()
        await redis_client.rpush(self.queue_key, str(task_id))
        logger.info(f"Task {task_id} added to queue")
        return True

    async def dequeue_task(self) -> Optional[int]:
        """从队列中取出任务"""
        redis_client = await self._get_redis()
        task_id = await redis_client.lpop(self.queue_key)
        if task_id:
            return int(task_id)
        return None

    async def get_queue_position(self, task_id: int) -> int:
        """获取任务在队列中的位置"""
        redis_client = await self._get_redis()
        queue = await redis_client.lrange(self.queue_key, 0, -1)

        for i, tid in enumerate(queue):
            if int(tid) == task_id:
                return i + 1
        return -1

    async def update_task_status(
        self,
        task_id: int,
        status: TaskStatus,
        db: AsyncSession,
        stage: Optional[TaskStage] = None,
        error_message: Optional[str] = None,
        progress: Optional[int] = None,
        progress_message: Optional[str] = None
    ):
        """更新任务状态"""
        result = await db.execute(
            select(Task).where(Task.id == task_id)
        )
        task = result.scalar_one_or_none()

        if not task:
            logger.error(f"Task {task_id} not found")
            return

        task.status = status

        if stage:
            task.current_stage = stage

        if error_message:
            task.error_message = error_message

        if progress is not None:
            task.progress = progress

        if progress_message:
            task.progress_message = progress_message

        # 更新时间戳
        if status == TaskStatus.RUNNING and not task.started_at:
            task.started_at = datetime.utcnow()
        elif status in [TaskStatus.SUCCESS, TaskStatus.FAILED, TaskStatus.CANCELLED]:
            task.completed_at = datetime.utcnow()
            if task.started_at:
                task.total_duration = (task.completed_at - task.started_at).total_seconds()

        await db.commit()
        logger.info(f"Task {task_id} status updated to {status.value}")

    async def cancel_task(self, task_id: int, db: AsyncSession):
        """取消任务"""
        # 从队列中移除
        redis_client = await self._get_redis()
        await redis_client.lrem(self.queue_key, 0, str(task_id))

        # 如果是当前任务，释放锁
        current_lock = await redis_client.get(self.lock_key)
        if current_lock and int(current_lock) == task_id:
            await self.release_lock(task_id)

        # 更新数据库状态
        await self.update_task_status(
            task_id,
            TaskStatus.CANCELLED,
            db,
            error_message="Task cancelled by user"
        )

    async def process_queue(self, db: AsyncSession):
        """处理任务队列（后台任务）"""
        while True:
            try:
                # 检查是否有锁
                redis_client = await self._get_redis()
                current_lock = await redis_client.get(self.lock_key)

                if not current_lock:
                    # 尝试从队列中取出任务
                    task_id = await self.dequeue_task()
                    if task_id:
                        # 尝试获取锁并执行
                        if await self.acquire_lock(task_id):
                            logger.info(f"Processing task {task_id} from queue")
                            # 这里应该调用实际的构建执行器
                            # await build_executor.execute(task_id)

                # 等待一段时间再检查
                await asyncio.sleep(5)

            except Exception as e:
                logger.error(f"Error in queue processor: {str(e)}")
                await asyncio.sleep(10)

    async def get_task_statistics(self, db: AsyncSession) -> dict:
        """获取任务统计信息"""
        # 总任务数
        total_result = await db.execute(
            select(Task)
        )
        total_tasks = len(total_result.all())

        # 成功任务数
        success_result = await db.execute(
            select(Task).where(Task.status == TaskStatus.SUCCESS)
        )
        success_tasks = len(success_result.all())

        # 失败任务数
        failed_result = await db.execute(
            select(Task).where(Task.status == TaskStatus.FAILED)
        )
        failed_tasks = len(failed_result.all())

        # 队列长度
        redis_client = await self._get_redis()
        queue_length = await redis_client.llen(self.queue_key)

        return {
            "total_tasks": total_tasks,
            "success_tasks": success_tasks,
            "failed_tasks": failed_tasks,
            "queue_length": queue_length,
            "success_rate": (success_tasks / total_tasks * 100) if total_tasks > 0 else 0
        }