import { Router } from 'express';
import { body, query, param, validationResult } from 'express-validator';
import { TaskStatus } from '@prisma/client';
import { getPrismaClient } from '../services/database';
import { AppError, asyncHandler } from '../middlewares/error';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { TaskLock, TaskQueue } from '../services/redis';
import { BuildExecutor } from '../services/buildExecutor';
import { logger } from '../utils/logger';
import { io } from '../server';

const router = Router();
const buildExecutor = new BuildExecutor();

// Validation middleware
const handleValidationErrors = (req: any, res: any, next: any) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new AppError(`Validation error: ${errors.array()[0].msg}`, 400);
  }
  next();
};

// Create task
router.post(
  '/create',
  authenticate,
  [
    body('unityBranch').notEmpty().withMessage('Unity branch is required'),
    body('flutterBranch').notEmpty().withMessage('Flutter branch is required'),
    body('unityArgs').optional().isObject(),
    body('flutterArgs').optional().isObject(),
  ],
  handleValidationErrors,
  asyncHandler(async (req: AuthRequest, res: any) => {
    const { unityBranch, flutterBranch, unityArgs = {}, flutterArgs = {} } = req.body;

    const prisma = getPrismaClient();

    // Check if there's a running task (global mutex lock)
    const isLocked = await TaskLock.isLocked();
    if (isLocked) {
      // Add to queue instead
      const task = await prisma.task.create({
        data: {
          status: TaskStatus.QUEUED,
          initiatorId: req.user!.id,
          unityBranch,
          flutterBranch,
          unityArgs,
          flutterArgs,
          progress: 0,
          progressMessage: 'Task queued',
        },
        include: {
          initiator: {
            select: {
              id: true,
              username: true,
            },
          },
        },
      });

      await TaskQueue.enqueue(task.id);

      logger.info(`Task ${task.id} created and queued by ${req.user!.username}`);

      // Emit WebSocket event
      io.emit('task_update', {
        taskId: task.taskUuid,
        status: 'queued',
        message: 'Task added to queue',
      });

      return res.status(201).json({
        message: 'Task created and added to queue',
        task,
      });
    }

    // Create and start task immediately
    const task = await prisma.task.create({
      data: {
        status: TaskStatus.PENDING,
        initiatorId: req.user!.id,
        unityBranch,
        flutterBranch,
        unityArgs,
        flutterArgs,
        progress: 0,
        progressMessage: 'Task created',
      },
      include: {
        initiator: {
          select: {
            id: true,
            username: true,
          },
        },
      },
    });

    // Start build execution
    buildExecutor.execute(task.id).catch(error => {
      logger.error(`Failed to execute task ${task.id}:`, error);
    });

    logger.info(`Task ${task.id} created by ${req.user!.username}`);

    // Emit WebSocket event
    io.emit('task_update', {
      taskId: task.taskUuid,
      status: 'created',
      message: 'Task created and started',
    });

    res.status(201).json({
      message: 'Task created successfully',
      task,
    });
  })
);

// Get current task
router.get(
  '/current',
  asyncHandler(async (req: any, res: any) => {
    const prisma = getPrismaClient();

    const task = await prisma.task.findFirst({
      where: {
        status: {
          in: [TaskStatus.RUNNING, TaskStatus.QUEUED],
        },
      },
      include: {
        initiator: {
          select: {
            id: true,
            username: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    res.json({ task });
  })
);

// Get task list
router.get(
  '/list',
  [
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('status').optional().isIn(Object.values(TaskStatus)),
  ],
  handleValidationErrors,
  asyncHandler(async (req: any, res: any) => {
    const page = parseInt(req.query.page || '1');
    const limit = parseInt(req.query.limit || '20');
    const status = req.query.status as TaskStatus | undefined;

    const prisma = getPrismaClient();

    const where = status ? { status } : {};

    const [tasks, total] = await Promise.all([
      prisma.task.findMany({
        where,
        include: {
          initiator: {
            select: {
              id: true,
              username: true,
            },
          },
          artifact: true,
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.task.count({ where }),
    ]);

    res.json({
      tasks,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    });
  })
);

// Get task by ID
router.get(
  '/:id',
  param('id').isInt(),
  handleValidationErrors,
  asyncHandler(async (req: any, res: any) => {
    const taskId = parseInt(req.params.id);

    const prisma = getPrismaClient();

    const task = await prisma.task.findUnique({
      where: { id: taskId },
      include: {
        initiator: {
          select: {
            id: true,
            username: true,
          },
        },
        artifact: true,
        stageLogs: {
          orderBy: {
            startedAt: 'asc',
          },
        },
      },
    });

    if (!task) {
      throw new AppError('Task not found', 404);
    }

    res.json({ task });
  })
);

// Cancel task
router.post(
  '/:id/cancel',
  authenticate,
  param('id').isInt(),
  handleValidationErrors,
  asyncHandler(async (req: AuthRequest, res: any) => {
    const taskId = parseInt(req.params.id);

    const prisma = getPrismaClient();

    const task = await prisma.task.findUnique({
      where: { id: taskId },
    });

    if (!task) {
      throw new AppError('Task not found', 404);
    }

    if (!['PENDING', 'QUEUED', 'RUNNING'].includes(task.status)) {
      throw new AppError('Task cannot be cancelled in current status', 400);
    }

    // Remove from queue if queued
    if (task.status === TaskStatus.QUEUED) {
      await TaskQueue.remove(taskId);
    }

    // Release lock if running
    if (task.status === TaskStatus.RUNNING) {
      await TaskLock.release(taskId);
    }

    // Update task status
    await prisma.task.update({
      where: { id: taskId },
      data: {
        status: TaskStatus.CANCELLED,
        completedAt: new Date(),
        errorMessage: `Cancelled by ${req.user!.username}`,
      },
    });

    logger.info(`Task ${taskId} cancelled by ${req.user!.username}`);

    // Emit WebSocket event
    io.emit('task_update', {
      taskId: task.taskUuid,
      status: 'cancelled',
      message: `Task cancelled by ${req.user!.username}`,
    });

    res.json({ message: 'Task cancelled successfully' });
  })
);

// Get task logs
router.get(
  '/:id/logs',
  param('id').isInt(),
  handleValidationErrors,
  asyncHandler(async (req: any, res: any) => {
    const taskId = parseInt(req.params.id);

    const prisma = getPrismaClient();

    const task = await prisma.task.findUnique({
      where: { id: taskId },
      include: {
        stageLogs: {
          orderBy: {
            startedAt: 'asc',
          },
        },
      },
    });

    if (!task) {
      throw new AppError('Task not found', 404);
    }

    res.json({
      taskId: task.id,
      logs: task.stageLogs,
      logFilePath: task.logFilePath,
    });
  })
);

// Get queue status
router.get(
  '/queue/status',
  asyncHandler(async (req: any, res: any) => {
    const [queueLength, queueTasks] = await Promise.all([
      TaskQueue.getLength(),
      TaskQueue.getAll(),
    ]);

    const prisma = getPrismaClient();

    const tasks = await prisma.task.findMany({
      where: {
        id: {
          in: queueTasks,
        },
      },
      select: {
        id: true,
        taskUuid: true,
        unityBranch: true,
        flutterBranch: true,
        createdAt: true,
        initiator: {
          select: {
            username: true,
          },
        },
      },
    });

    res.json({
      queueLength,
      tasks,
    });
  })
);

export default router;