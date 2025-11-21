import { Router } from 'express';
import { param, query } from 'express-validator';
import path from 'path';
import fs from 'fs/promises';
import { getPrismaClient } from '../services/database';
import { AppError, asyncHandler } from '../middlewares/error';
import { authenticate, authorize, AuthRequest } from '../middlewares/auth';
import { UserRole } from '@prisma/client';
import { logger } from '../utils/logger';

const router = Router();

// Get artifacts list
router.get(
  '/list',
  [
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('isArchived').optional().isBoolean(),
  ],
  asyncHandler(async (req: any, res: any) => {
    const page = parseInt(req.query.page || '1');
    const limit = parseInt(req.query.limit || '20');
    const isArchived = req.query.isArchived === 'true';

    const prisma = getPrismaClient();

    const where = { isArchived };

    const [artifacts, total] = await Promise.all([
      prisma.artifact.findMany({
        where,
        include: {
          task: {
            select: {
              id: true,
              taskUuid: true,
              unityBranch: true,
              flutterBranch: true,
              status: true,
              initiator: {
                select: {
                  username: true,
                },
              },
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.artifact.count({ where }),
    ]);

    res.json({
      artifacts,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    });
  })
);

// Get artifact by ID
router.get(
  '/:id',
  param('id').isInt(),
  asyncHandler(async (req: any, res: any) => {
    const artifactId = parseInt(req.params.id);

    const prisma = getPrismaClient();

    const artifact = await prisma.artifact.findUnique({
      where: { id: artifactId },
      include: {
        task: {
          select: {
            id: true,
            taskUuid: true,
            unityBranch: true,
            flutterBranch: true,
            status: true,
            createdAt: true,
            initiator: {
              select: {
                username: true,
              },
            },
          },
        },
      },
    });

    if (!artifact) {
      throw new AppError('Artifact not found', 404);
    }

    res.json({ artifact });
  })
);

// Download artifact
router.get(
  '/:id/download',
  param('id').isInt(),
  asyncHandler(async (req: any, res: any) => {
    const artifactId = parseInt(req.params.id);

    const prisma = getPrismaClient();

    const artifact = await prisma.artifact.findUnique({
      where: { id: artifactId },
    });

    if (!artifact) {
      throw new AppError('Artifact not found', 404);
    }

    // Check if file exists
    try {
      await fs.access(artifact.filePath);
    } catch {
      throw new AppError('Artifact file not found on disk', 404);
    }

    // Update download count
    await prisma.artifact.update({
      where: { id: artifactId },
      data: {
        downloadCount: {
          increment: 1,
        },
        lastDownloadedAt: new Date(),
      },
    });

    logger.info(`Artifact ${artifactId} downloaded`);

    // Send file
    res.download(artifact.filePath, artifact.fileName);
  })
);

// Archive artifact
router.post(
  '/:id/archive',
  authenticate,
  param('id').isInt(),
  asyncHandler(async (req: AuthRequest, res: any) => {
    const artifactId = parseInt(req.params.id);

    const prisma = getPrismaClient();

    const artifact = await prisma.artifact.findUnique({
      where: { id: artifactId },
    });

    if (!artifact) {
      throw new AppError('Artifact not found', 404);
    }

    if (artifact.isArchived) {
      throw new AppError('Artifact is already archived', 400);
    }

    await prisma.artifact.update({
      where: { id: artifactId },
      data: {
        isArchived: true,
        archivedAt: new Date(),
      },
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user!.id,
        action: 'archive_artifact',
        resourceType: 'artifact',
        resourceId: artifactId.toString(),
        result: 'success',
      },
    });

    logger.info(`Artifact ${artifactId} archived by ${req.user!.username}`);

    res.json({ message: 'Artifact archived successfully' });
  })
);

// Delete artifact (admin only)
router.delete(
  '/:id',
  authenticate,
  authorize(UserRole.ADMIN),
  param('id').isInt(),
  asyncHandler(async (req: AuthRequest, res: any) => {
    const artifactId = parseInt(req.params.id);

    const prisma = getPrismaClient();

    const artifact = await prisma.artifact.findUnique({
      where: { id: artifactId },
    });

    if (!artifact) {
      throw new AppError('Artifact not found', 404);
    }

    // Delete file from disk
    try {
      await fs.unlink(artifact.filePath);
    } catch (error) {
      logger.error(`Failed to delete artifact file: ${artifact.filePath}`, error);
    }

    // Delete from database
    await prisma.artifact.delete({
      where: { id: artifactId },
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user!.id,
        action: 'delete_artifact',
        resourceType: 'artifact',
        resourceId: artifactId.toString(),
        result: 'success',
      },
    });

    logger.info(`Artifact ${artifactId} deleted by ${req.user!.username}`);

    res.json({ message: 'Artifact deleted successfully' });
  })
);

// Cleanup old artifacts (admin only)
router.post(
  '/cleanup',
  authenticate,
  authorize(UserRole.ADMIN),
  asyncHandler(async (req: AuthRequest, res: any) => {
    const { days = 30, count = 100 } = req.body;

    const prisma = getPrismaClient();

    // Find artifacts to delete
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);

    const artifactsToDelete = await prisma.artifact.findMany({
      where: {
        OR: [
          {
            createdAt: {
              lt: cutoffDate,
            },
          },
        ],
      },
      orderBy: {
        createdAt: 'asc',
      },
      skip: count,
    });

    // Delete artifacts
    let deletedCount = 0;
    for (const artifact of artifactsToDelete) {
      try {
        await fs.unlink(artifact.filePath);
      } catch (error) {
        logger.error(`Failed to delete artifact file: ${artifact.filePath}`, error);
      }

      await prisma.artifact.delete({
        where: { id: artifact.id },
      });

      deletedCount++;
    }

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user!.id,
        action: 'cleanup_artifacts',
        resourceType: 'artifact',
        payload: { days, count, deletedCount },
        result: 'success',
      },
    });

    logger.info(`Artifact cleanup completed by ${req.user!.username}: ${deletedCount} artifacts deleted`);

    res.json({
      message: 'Cleanup completed',
      deletedCount,
    });
  })
);

export default router;