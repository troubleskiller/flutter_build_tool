import { Router } from 'express';
import { query } from 'express-validator';
import { TaskStatus } from '@prisma/client';
import { getPrismaClient } from '../services/database';
import { asyncHandler } from '../middlewares/error';

const router = Router();

// Get summary statistics
router.get(
  '/summary',
  [query('days').optional().isInt({ min: 1, max: 365 })],
  asyncHandler(async (req: any, res: any) => {
    const days = parseInt(req.query.days || '30');
    const prisma = getPrismaClient();

    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    // Get task counts
    const [totalTasks, successTasks, failedTasks, todayTasks] = await Promise.all([
      prisma.task.count({
        where: {
          createdAt: {
            gte: startDate,
          },
        },
      }),
      prisma.task.count({
        where: {
          createdAt: {
            gte: startDate,
          },
          status: TaskStatus.SUCCESS,
        },
      }),
      prisma.task.count({
        where: {
          createdAt: {
            gte: startDate,
          },
          status: TaskStatus.FAILED,
        },
      }),
      prisma.task.count({
        where: {
          createdAt: {
            gte: new Date(new Date().setHours(0, 0, 0, 0)),
          },
        },
      }),
    ]);

    // Calculate average duration
    const avgDurationResult = await prisma.task.aggregate({
      _avg: {
        totalDuration: true,
      },
      where: {
        createdAt: {
          gte: startDate,
        },
        status: TaskStatus.SUCCESS,
        totalDuration: {
          not: null,
        },
      },
    });

    const successRate = totalTasks > 0 ? (successTasks / totalTasks) * 100 : 0;
    const avgDuration = avgDurationResult._avg.totalDuration || 0;

    res.json({
      totalTasks,
      successCount: successTasks,
      failedCount: failedTasks,
      successRate: Math.round(successRate * 100) / 100,
      avgDuration: Math.round(avgDuration / 60), // Convert to minutes
      todayBuilds: todayTasks,
      period: days,
    });
  })
);

// Get statistics by branch
router.get(
  '/by-branch',
  [
    query('type').isIn(['unity', 'flutter']),
    query('days').optional().isInt({ min: 1, max: 365 }),
  ],
  asyncHandler(async (req: any, res: any) => {
    const branchType = req.query.type;
    const days = parseInt(req.query.days || '30');

    const prisma = getPrismaClient();

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    // Get unique branches with statistics
    const tasks = await prisma.task.findMany({
      where: {
        createdAt: {
          gte: startDate,
        },
      },
      select: {
        id: true,
        unityBranch: true,
        flutterBranch: true,
        status: true,
        totalDuration: true,
      },
    });

    // Group by branch
    const branchStats = new Map<string, any>();

    tasks.forEach((task) => {
      const branch = branchType === 'unity' ? task.unityBranch : task.flutterBranch;

      if (!branchStats.has(branch)) {
        branchStats.set(branch, {
          branchName: branch,
          taskCount: 0,
          successCount: 0,
          totalDuration: 0,
          durations: [],
        });
      }

      const stats = branchStats.get(branch);
      stats.taskCount++;

      if (task.status === TaskStatus.SUCCESS) {
        stats.successCount++;
        if (task.totalDuration) {
          stats.totalDuration += task.totalDuration;
          stats.durations.push(task.totalDuration);
        }
      }
    });

    // Calculate final statistics
    const result = Array.from(branchStats.values()).map((stats) => ({
      branchName: stats.branchName,
      taskCount: stats.taskCount,
      successRate: stats.taskCount > 0
        ? Math.round((stats.successCount / stats.taskCount) * 10000) / 100
        : 0,
      avgDuration: stats.durations.length > 0
        ? Math.round(stats.totalDuration / stats.durations.length / 60)
        : 0,
    }));

    res.json(result);
  })
);

// Get time series data
router.get(
  '/time-series',
  [query('days').optional().isInt({ min: 1, max: 30 })],
  asyncHandler(async (req: any, res: any) => {
    const days = parseInt(req.query.days || '7');
    const prisma = getPrismaClient();

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    startDate.setHours(0, 0, 0, 0);

    const tasks = await prisma.task.findMany({
      where: {
        createdAt: {
          gte: startDate,
        },
      },
      select: {
        createdAt: true,
        status: true,
      },
    });

    // Group by date
    const dateStats = new Map<string, any>();

    // Initialize all dates
    for (let i = 0; i < days; i++) {
      const date = new Date(startDate);
      date.setDate(date.getDate() + i);
      const dateKey = date.toISOString().split('T')[0];

      dateStats.set(dateKey, {
        date: dateKey,
        taskCount: 0,
        successCount: 0,
        failedCount: 0,
      });
    }

    // Count tasks
    tasks.forEach((task) => {
      const dateKey = task.createdAt.toISOString().split('T')[0];

      if (dateStats.has(dateKey)) {
        const stats = dateStats.get(dateKey);
        stats.taskCount++;

        if (task.status === TaskStatus.SUCCESS) {
          stats.successCount++;
        } else if (task.status === TaskStatus.FAILED) {
          stats.failedCount++;
        }
      }
    });

    const result = Array.from(dateStats.values()).sort((a, b) =>
      a.date.localeCompare(b.date)
    );

    res.json(result);
  })
);

// Get top users
router.get(
  '/top-users',
  [
    query('days').optional().isInt({ min: 1, max: 365 }),
    query('limit').optional().isInt({ min: 1, max: 50 }),
  ],
  asyncHandler(async (req: any, res: any) => {
    const days = parseInt(req.query.days || '30');
    const limit = parseInt(req.query.limit || '10');

    const prisma = getPrismaClient();

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    // Get tasks with initiator
    const tasks = await prisma.task.findMany({
      where: {
        createdAt: {
          gte: startDate,
        },
        initiatorId: {
          not: null,
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
    });

    // Group by user
    const userStats = new Map<number, any>();

    tasks.forEach((task) => {
      if (!task.initiator) return;

      const userId = task.initiator.id;

      if (!userStats.has(userId)) {
        userStats.set(userId, {
          username: task.initiator.username,
          taskCount: 0,
          successCount: 0,
        });
      }

      const stats = userStats.get(userId);
      stats.taskCount++;

      if (task.status === TaskStatus.SUCCESS) {
        stats.successCount++;
      }
    });

    // Calculate and sort
    const result = Array.from(userStats.values())
      .map((stats) => ({
        username: stats.username,
        taskCount: stats.taskCount,
        successCount: stats.successCount,
        successRate: stats.taskCount > 0
          ? Math.round((stats.successCount / stats.taskCount) * 10000) / 100
          : 0,
      }))
      .sort((a, b) => b.taskCount - a.taskCount)
      .slice(0, limit);

    res.json(result);
  })
);

export default router;