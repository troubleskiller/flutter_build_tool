import socketio
from typing import Dict, List
import json
from loguru import logger

# 创建Socket.IO服务器
sio = socketio.AsyncServer(
    async_mode='asgi',
    cors_allowed_origins='*',
    logger=False,
    engineio_logger=False
)

# 创建ASGI应用
socket_app = socketio.ASGIApp(
    sio,
    socketio_path='socket.io'
)

# 存储连接的客户端
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[str]] = {}
        self.user_sessions: Dict[str, str] = {}

    async def connect(self, sid: str, user_id: str = None):
        """处理客户端连接"""
        if user_id:
            if user_id not in self.active_connections:
                self.active_connections[user_id] = []
            self.active_connections[user_id].append(sid)
            self.user_sessions[sid] = user_id
        logger.info(f"Client {sid} connected (user: {user_id})")

    async def disconnect(self, sid: str):
        """处理客户端断开连接"""
        user_id = self.user_sessions.get(sid)
        if user_id:
            if user_id in self.active_connections:
                self.active_connections[user_id].remove(sid)
                if not self.active_connections[user_id]:
                    del self.active_connections[user_id]
            del self.user_sessions[sid]
        logger.info(f"Client {sid} disconnected")

    async def send_to_user(self, user_id: str, event: str, data: dict):
        """向特定用户发送消息"""
        if user_id in self.active_connections:
            for sid in self.active_connections[user_id]:
                await sio.emit(event, data, to=sid)

    async def broadcast(self, event: str, data: dict, exclude: str = None):
        """广播消息"""
        await sio.emit(event, data, skip_sid=exclude)

    async def send_task_update(self, task_id: str, status: str, data: dict):
        """发送任务更新"""
        await self.broadcast('task_update', {
            'task_id': task_id,
            'status': status,
            'data': data
        })

    async def send_log_stream(self, task_id: str, log_line: str, stage: str = None):
        """发送实时日志流"""
        await self.broadcast('log_stream', {
            'task_id': task_id,
            'log': log_line,
            'stage': stage,
            'timestamp': None  # 将在发送时添加时间戳
        })

# 创建连接管理器实例
manager = ConnectionManager()

# Socket.IO事件处理器
@sio.event
async def connect(sid, environ):
    """处理连接事件"""
    await manager.connect(sid)
    await sio.emit('connected', {'message': 'Connected to build server'}, to=sid)

@sio.event
async def disconnect(sid):
    """处理断开连接事件"""
    await manager.disconnect(sid)

@sio.event
async def join_task(sid, data):
    """加入特定任务的房间"""
    task_id = data.get('task_id')
    if task_id:
        await sio.enter_room(sid, f'task_{task_id}')
        await sio.emit('joined_task', {'task_id': task_id}, to=sid)

@sio.event
async def leave_task(sid, data):
    """离开特定任务的房间"""
    task_id = data.get('task_id')
    if task_id:
        await sio.leave_room(sid, f'task_{task_id}')
        await sio.emit('left_task', {'task_id': task_id}, to=sid)

@sio.event
async def subscribe_logs(sid, data):
    """订阅日志流"""
    task_id = data.get('task_id')
    if task_id:
        await sio.enter_room(sid, f'logs_{task_id}')
        await sio.emit('subscribed_logs', {'task_id': task_id}, to=sid)