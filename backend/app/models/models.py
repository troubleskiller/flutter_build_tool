from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, Float, JSON, ForeignKey, Enum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum

from backend.app.core.database import Base


class UserRole(str, enum.Enum):
    ADMIN = "admin"
    USER = "user"

class TaskStatus(str, enum.Enum):
    PENDING = "pending"
    QUEUED = "queued"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"
    CANCELLED = "cancelled"

class TaskStage(str, enum.Enum):
    UNITY_FETCH = "unity_fetch"
    UNITY_BUILD = "unity_build"
    FLUTTER_FETCH = "flutter_fetch"
    FLUTTER_BUILD = "flutter_build"
    ARTIFACT_SAVE = "artifact_save"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(200), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.USER)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime)

    # 关系
    tasks = relationship("Task", back_populates="initiator_user")
    audit_logs = relationship("AuditLog", back_populates="user")

class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    task_uuid = Column(String(36), unique=True, index=True, nullable=False)
    status = Column(Enum(TaskStatus), default=TaskStatus.PENDING, index=True)
    current_stage = Column(Enum(TaskStage), nullable=True)

    # 用户信息
    initiator_id = Column(Integer, ForeignKey("users.id"))
    initiator_user = relationship("User", back_populates="tasks")

    # Git分支信息
    unity_branch = Column(String(100), nullable=False)
    flutter_branch = Column(String(100), nullable=False)
    unity_commit = Column(String(40))
    flutter_commit = Column(String(40))

    # 自定义参数
    unity_args = Column(JSON, default={})
    flutter_args = Column(JSON, default={})

    # 时间信息
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    started_at = Column(DateTime)
    completed_at = Column(DateTime)

    # 各阶段耗时（秒）
    unity_fetch_duration = Column(Float)
    unity_build_duration = Column(Float)
    flutter_fetch_duration = Column(Float)
    flutter_build_duration = Column(Float)
    total_duration = Column(Float)

    # 日志路径
    log_file_path = Column(String(500))
    error_message = Column(Text)

    # 进度信息
    progress = Column(Integer, default=0)
    progress_message = Column(String(200))

    # 关系
    artifact = relationship("Artifact", back_populates="task", uselist=False)
    stage_logs = relationship("StageLog", back_populates="task")

class Artifact(Base):
    __tablename__ = "artifacts"

    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"), unique=True)
    task = relationship("Task", back_populates="artifact")

    file_name = Column(String(200), nullable=False)
    file_path = Column(String(500), nullable=False)
    file_size = Column(Integer)  # 字节
    checksum = Column(String(64))  # SHA256
    download_url = Column(String(500))

    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    download_count = Column(Integer, default=0)
    last_downloaded_at = Column(DateTime)
    is_archived = Column(Boolean, default=False)
    archived_at = Column(DateTime)

class StageLog(Base):
    __tablename__ = "stage_logs"

    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"))
    task = relationship("Task", back_populates="stage_logs")

    stage = Column(Enum(TaskStage), nullable=False)
    log_content = Column(Text)
    started_at = Column(DateTime)
    completed_at = Column(DateTime)
    success = Column(Boolean)
    error_message = Column(Text)

class RepoConfig(Base):
    __tablename__ = "repo_configs"

    id = Column(Integer, primary_key=True, index=True)
    repo_type = Column(String(20), unique=True, index=True)  # "unity" or "flutter"
    repo_url = Column(String(500), nullable=False)
    repo_path = Column(String(500), nullable=False)
    default_branch = Column(String(100), default="main")

    # 认证信息（加密存储）
    auth_type = Column(String(20))  # "ssh", "https", "token"
    auth_credentials = Column(Text)  # 加密的凭证

    # 镜像配置
    use_mirror = Column(Boolean, default=False)
    mirror_url = Column(String(500))

    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class CleanupPolicy(Base):
    __tablename__ = "cleanup_policies"

    id = Column(Integer, primary_key=True, index=True)
    policy_name = Column(String(50), unique=True, nullable=False)
    is_active = Column(Boolean, default=True)

    # 保留策略
    retention_days = Column(Integer, default=30)
    retention_count = Column(Integer, default=100)

    # 清理策略
    clean_failed_tasks = Column(Boolean, default=False)
    archive_before_delete = Column(Boolean, default=True)
    archive_path = Column(String(500))

    # 执行计划
    schedule_cron = Column(String(50))  # Cron表达式
    last_run_at = Column(DateTime)
    next_run_at = Column(DateTime)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    user = relationship("User", back_populates="audit_logs")

    action = Column(String(100), nullable=False, index=True)
    resource_type = Column(String(50))  # "task", "artifact", "config", etc.
    resource_id = Column(String(100))
    payload = Column(JSON)
    result = Column(String(20))  # "success", "failed"
    ip_address = Column(String(45))
    user_agent = Column(String(500))

    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

class Statistics(Base):
    __tablename__ = "statistics"

    id = Column(Integer, primary_key=True, index=True)
    date = Column(DateTime, index=True, nullable=False)

    # 按维度统计
    dimension_type = Column(String(20))  # "branch", "user", "date"
    dimension_value = Column(String(100))

    # 统计数据
    success_count = Column(Integer, default=0)
    failed_count = Column(Integer, default=0)
    total_count = Column(Integer, default=0)
    avg_duration = Column(Float)
    min_duration = Column(Float)
    max_duration = Column(Float)

    # Unity和Flutter分别的成功率
    unity_success_rate = Column(Float)
    flutter_success_rate = Column(Float)

    last_task_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)