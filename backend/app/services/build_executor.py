import asyncio
import subprocess
import os
import json
from pathlib import Path
from typing import Optional, Dict, Any
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy import select
import hashlib
import uuid
from backend.app.models.models import Task, TaskStatus, TaskStage, Artifact, StageLog
from backend.app.core.config import settings
from backend.app.core.websocket import manager as ws_manager
from backend.app.services.task_manager import TaskManager
from loguru import logger
import git

class BuildExecutor:
    """构建执行器，负责执行Unity和Flutter构建任务"""

    def __init__(self):
        self.task_manager = TaskManager()
        # 创建独立的数据库连接（用于异步任务）
        self.engine = create_async_engine(settings.DATABASE_URL)
        self.AsyncSessionLocal = async_sessionmaker(
            self.engine,
            class_=AsyncSession,
            expire_on_commit=False
        )

    async def get_db(self):
        """获取数据库会话"""
        async with self.AsyncSessionLocal() as session:
            return session

    async def execute_task(self, task_id: int):
        """异步执行构建任务"""
        # 创建后台任务
        asyncio.create_task(self._execute_task_background(task_id))

    async def _execute_task_background(self, task_id: int):
        """后台执行构建任务"""
        db = await self.get_db()

        try:
            # 获取任务信息
            result = await db.execute(
                select(Task).where(Task.id == task_id)
            )
            task = result.scalar_one_or_none()

            if not task:
                logger.error(f"Task {task_id} not found")
                return

            # 尝试获取全局锁
            if not await self.task_manager.acquire_lock(task_id):
                logger.warning(f"Task {task_id} failed to acquire lock, staying in queue")
                return

            # 更新任务状态为运行中
            await self.task_manager.update_task_status(
                task_id, TaskStatus.RUNNING, db,
                progress=0,
                progress_message="Starting build process"
            )

            # 发送WebSocket通知
            await ws_manager.send_task_update(
                task.task_uuid, "started", {"message": "Build process started"}
            )

            # 执行构建阶段
            success = True

            # 1. Unity拉取阶段
            if success:
                success = await self._execute_unity_fetch(task, db)

            # 2. Unity构建阶段
            if success:
                success = await self._execute_unity_build(task, db)

            # 3. Flutter拉取阶段
            if success:
                success = await self._execute_flutter_fetch(task, db)

            # 4. Flutter构建阶段
            if success:
                success = await self._execute_flutter_build(task, db)

            # 5. 保存产物
            if success:
                success = await self._save_artifact(task, db)

            # 更新最终状态
            final_status = TaskStatus.SUCCESS if success else TaskStatus.FAILED
            await self.task_manager.update_task_status(
                task_id, final_status, db,
                progress=100 if success else task.progress,
                progress_message="Build completed" if success else "Build failed"
            )

            # 发送完成通知
            await ws_manager.send_task_update(
                task.task_uuid,
                "completed" if success else "failed",
                {"success": success}
            )

        except Exception as e:
            logger.error(f"Task {task_id} execution error: {str(e)}")
            await self.task_manager.update_task_status(
                task_id, TaskStatus.FAILED, db,
                error_message=str(e)
            )
        finally:
            # 释放全局锁
            await self.task_manager.release_lock(task_id)
            await db.close()

    async def _execute_unity_fetch(self, task: Task, db: AsyncSession) -> bool:
        """执行Unity仓库拉取"""
        try:
            await self.task_manager.update_task_status(
                task.id, TaskStatus.RUNNING, db,
                stage=TaskStage.UNITY_FETCH,
                progress=10,
                progress_message="Fetching Unity repository"
            )

            # 创建日志记录
            stage_log = StageLog(
                task_id=task.id,
                stage=TaskStage.UNITY_FETCH,
                started_at=datetime.utcnow()
            )
            db.add(stage_log)

            # 获取Unity仓库配置
            repo_path = settings.UNITY_REPO_PATH
            os.makedirs(repo_path, exist_ok=True)

            # 执行Git操作
            if not os.path.exists(os.path.join(repo_path, '.git')):
                # 克隆仓库
                repo = git.Repo.clone_from(
                    settings.UNITY_REPO_URL,
                    repo_path,
                    branch=task.unity_branch
                )
                await ws_manager.send_log_stream(
                    task.task_uuid,
                    f"Cloned Unity repository to {repo_path}",
                    "unity_fetch"
                )
            else:
                # 更新仓库
                repo = git.Repo(repo_path)
                origin = repo.remote('origin')
                origin.fetch()

                # 切换到指定分支
                if task.unity_branch in repo.heads:
                    repo.heads[task.unity_branch].checkout()
                else:
                    repo.create_head(task.unity_branch, origin.refs[task.unity_branch])
                    repo.heads[task.unity_branch].checkout()

                # 拉取最新代码
                origin.pull()
                await ws_manager.send_log_stream(
                    task.task_uuid,
                    f"Updated Unity repository to branch {task.unity_branch}",
                    "unity_fetch"
                )

            # 记录commit信息
            task.unity_commit = repo.head.commit.hexsha

            # 完成日志记录
            stage_log.completed_at = datetime.utcnow()
            stage_log.success = True
            stage_log.log_content = f"Successfully fetched Unity branch {task.unity_branch}"

            # 记录耗时
            task.unity_fetch_duration = (stage_log.completed_at - stage_log.started_at).total_seconds()

            await db.commit()
            return True

        except Exception as e:
            logger.error(f"Unity fetch failed: {str(e)}")
            await ws_manager.send_log_stream(
                task.task_uuid,
                f"Unity fetch error: {str(e)}",
                "unity_fetch"
            )
            task.error_message = f"Unity fetch failed: {str(e)}"
            await db.commit()
            return False

    async def _execute_unity_build(self, task: Task, db: AsyncSession) -> bool:
        """执行Unity构建"""
        try:
            await self.task_manager.update_task_status(
                task.id, TaskStatus.RUNNING, db,
                stage=TaskStage.UNITY_BUILD,
                progress=30,
                progress_message="Building Unity project"
            )

            # 创建日志记录
            stage_log = StageLog(
                task_id=task.id,
                stage=TaskStage.UNITY_BUILD,
                started_at=datetime.utcnow()
            )
            db.add(stage_log)

            # 构建Unity命令
            unity_args = task.unity_args or {}
            build_cmd = [
                settings.UNITY_EDITOR_PATH,
                "-batchmode",
                "-quit",
                "-projectPath", settings.UNITY_REPO_PATH,
                "-executeMethod", "BuildScript.ExportToFlutter"
            ]

            # 添加自定义参数
            for key, value in unity_args.items():
                build_cmd.extend([f"-{key}", str(value)])

            # 执行构建
            process = await asyncio.create_subprocess_exec(
                *build_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            # 实时读取输出
            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                log_line = line.decode('utf-8').strip()
                if log_line:
                    await ws_manager.send_log_stream(
                        task.task_uuid, log_line, "unity_build"
                    )

            # 等待进程结束
            returncode = await process.wait()

            if returncode == 0:
                stage_log.completed_at = datetime.utcnow()
                stage_log.success = True
                stage_log.log_content = "Unity build completed successfully"
                task.unity_build_duration = (stage_log.completed_at - stage_log.started_at).total_seconds()
                await db.commit()
                return True
            else:
                stderr = await process.stderr.read()
                error_msg = stderr.decode('utf-8')
                stage_log.success = False
                stage_log.error_message = error_msg
                task.error_message = f"Unity build failed: {error_msg}"
                await db.commit()
                return False

        except Exception as e:
            logger.error(f"Unity build failed: {str(e)}")
            task.error_message = f"Unity build error: {str(e)}"
            await db.commit()
            return False

    async def _execute_flutter_fetch(self, task: Task, db: AsyncSession) -> bool:
        """执行Flutter仓库拉取"""
        try:
            await self.task_manager.update_task_status(
                task.id, TaskStatus.RUNNING, db,
                stage=TaskStage.FLUTTER_FETCH,
                progress=50,
                progress_message="Fetching Flutter repository"
            )

            # 创建日志记录
            stage_log = StageLog(
                task_id=task.id,
                stage=TaskStage.FLUTTER_FETCH,
                started_at=datetime.utcnow()
            )
            db.add(stage_log)

            # 获取Flutter仓库配置
            repo_path = settings.FLUTTER_REPO_PATH
            os.makedirs(repo_path, exist_ok=True)

            # 执行Git操作（类似Unity）
            if not os.path.exists(os.path.join(repo_path, '.git')):
                repo = git.Repo.clone_from(
                    settings.FLUTTER_REPO_URL,
                    repo_path,
                    branch=task.flutter_branch
                )
            else:
                repo = git.Repo(repo_path)
                origin = repo.remote('origin')
                origin.fetch()

                if task.flutter_branch in repo.heads:
                    repo.heads[task.flutter_branch].checkout()
                else:
                    repo.create_head(task.flutter_branch, origin.refs[task.flutter_branch])
                    repo.heads[task.flutter_branch].checkout()

                origin.pull()

            task.flutter_commit = repo.head.commit.hexsha

            stage_log.completed_at = datetime.utcnow()
            stage_log.success = True
            stage_log.log_content = f"Successfully fetched Flutter branch {task.flutter_branch}"
            task.flutter_fetch_duration = (stage_log.completed_at - stage_log.started_at).total_seconds()

            await db.commit()
            return True

        except Exception as e:
            logger.error(f"Flutter fetch failed: {str(e)}")
            task.error_message = f"Flutter fetch failed: {str(e)}"
            await db.commit()
            return False

    async def _execute_flutter_build(self, task: Task, db: AsyncSession) -> bool:
        """执行Flutter构建"""
        try:
            await self.task_manager.update_task_status(
                task.id, TaskStatus.RUNNING, db,
                stage=TaskStage.FLUTTER_BUILD,
                progress=70,
                progress_message="Building Flutter APK"
            )

            # 创建日志记录
            stage_log = StageLog(
                task_id=task.id,
                stage=TaskStage.FLUTTER_BUILD,
                started_at=datetime.utcnow()
            )
            db.add(stage_log)

            # 切换到Flutter项目目录
            os.chdir(settings.FLUTTER_REPO_PATH)

            # 执行flutter pub get
            pub_get_cmd = [settings.FLUTTER_SDK_PATH + "/bin/flutter", "pub", "get"]
            process = await asyncio.create_subprocess_exec(
                *pub_get_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await process.wait()

            # 构建Flutter APK
            flutter_args = task.flutter_args or {}
            build_cmd = [
                settings.FLUTTER_SDK_PATH + "/bin/flutter",
                "build", "apk",
                "--release"
            ]

            # 添加自定义参数
            for key, value in flutter_args.items():
                build_cmd.append(f"--{key}={value}")

            # 执行构建
            process = await asyncio.create_subprocess_exec(
                *build_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            # 实时读取输出
            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                log_line = line.decode('utf-8').strip()
                if log_line:
                    await ws_manager.send_log_stream(
                        task.task_uuid, log_line, "flutter_build"
                    )

            returncode = await process.wait()

            if returncode == 0:
                stage_log.completed_at = datetime.utcnow()
                stage_log.success = True
                stage_log.log_content = "Flutter build completed successfully"
                task.flutter_build_duration = (stage_log.completed_at - stage_log.started_at).total_seconds()
                await db.commit()
                return True
            else:
                stderr = await process.stderr.read()
                error_msg = stderr.decode('utf-8')
                stage_log.success = False
                stage_log.error_message = error_msg
                task.error_message = f"Flutter build failed: {error_msg}"
                await db.commit()
                return False

        except Exception as e:
            logger.error(f"Flutter build failed: {str(e)}")
            task.error_message = f"Flutter build error: {str(e)}"
            await db.commit()
            return False

    async def _save_artifact(self, task: Task, db: AsyncSession) -> bool:
        """保存构建产物"""
        try:
            await self.task_manager.update_task_status(
                task.id, TaskStatus.RUNNING, db,
                stage=TaskStage.ARTIFACT_SAVE,
                progress=90,
                progress_message="Saving build artifact"
            )

            # APK文件路径
            apk_source = Path(settings.FLUTTER_REPO_PATH) / "build/app/outputs/flutter-apk/app-release.apk"

            if not apk_source.exists():
                task.error_message = "APK file not found after build"
                await db.commit()
                return False

            # 生成文件名
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            file_name = f"{timestamp}_{task.task_uuid}.apk"
            artifact_dir = Path(settings.ARTIFACTS_DIR)
            artifact_dir.mkdir(exist_ok=True)
            artifact_path = artifact_dir / file_name

            # 复制文件
            import shutil
            shutil.copy2(apk_source, artifact_path)

            # 计算文件哈希
            with open(artifact_path, 'rb') as f:
                file_hash = hashlib.sha256(f.read()).hexdigest()

            # 获取文件大小
            file_size = artifact_path.stat().st_size

            # 创建产物记录
            artifact = Artifact(
                task_id=task.id,
                file_name=file_name,
                file_path=str(artifact_path),
                file_size=file_size,
                checksum=file_hash,
                download_url=f"/api/v1/artifacts/{task.id}/download"
            )
            db.add(artifact)

            await db.commit()
            logger.info(f"Artifact saved: {file_name}")
            return True

        except Exception as e:
            logger.error(f"Failed to save artifact: {str(e)}")
            task.error_message = f"Artifact save error: {str(e)}"
            await db.commit()
            return False