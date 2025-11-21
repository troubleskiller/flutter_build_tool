import { Router } from 'express';
import simpleGit from 'simple-git';
import { body, param } from 'express-validator';
import { getPrismaClient } from '../services/database';
import { AppError, asyncHandler } from '../middlewares/error';
import { authenticate, authorize, AuthRequest } from '../middlewares/auth';
import { UserRole } from '@prisma/client';
import { logger } from '../utils/logger';
import { config } from '../config';

const router = Router();

// Get repository configurations
router.get(
  '/repos',
  asyncHandler(async (req: any, res: any) => {
    const prisma = getPrismaClient();

    const configs = await prisma.repoConfig.findMany();

    res.json({ configs });
  })
);

// Create or update repository configuration (admin only)
router.post(
  '/repos',
  authenticate,
  authorize(UserRole.ADMIN),
  [
    body('repoType').isIn(['unity', 'flutter']),
    body('repoUrl').isURL(),
    body('repoPath').notEmpty(),
    body('defaultBranch').optional().notEmpty(),
    body('authType').optional().isIn(['ssh', 'https', 'token']),
  ],
  asyncHandler(async (req: AuthRequest, res: any) => {
    const { repoType, repoUrl, repoPath, defaultBranch = 'main', authType } = req.body;

    const prisma = getPrismaClient();

    const existingConfig = await prisma.repoConfig.findUnique({
      where: { repoType },
    });

    let repoConfig;

    if (existingConfig) {
      // Update existing
      repoConfig = await prisma.repoConfig.update({
        where: { repoType },
        data: {
          repoUrl,
          repoPath,
          defaultBranch,
          authType,
        },
      });
    } else {
      // Create new
      repoConfig = await prisma.repoConfig.create({
        data: {
          repoType,
          repoUrl,
          repoPath,
          defaultBranch,
          authType,
        },
      });
    }

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user!.id,
        action: existingConfig ? 'update_repo_config' : 'create_repo_config',
        resourceType: 'repo_config',
        resourceId: repoType,
        result: 'success',
      },
    });

    logger.info(`Repo config for ${repoType} updated by ${req.user!.username}`);

    res.json({
      message: 'Repository configuration saved',
      config: repoConfig,
    });
  })
);

// Get repository branches
router.get(
  '/repos/:repoType/branches',
  param('repoType').isIn(['unity', 'flutter']),
  asyncHandler(async (req: any, res: any) => {
    const repoType = req.params.repoType;

    const prisma = getPrismaClient();

    const repoConfig = await prisma.repoConfig.findUnique({
      where: { repoType },
    });

    if (!repoConfig) {
      throw new AppError(`Repository configuration for ${repoType} not found`, 404);
    }

    try {
      const git = simpleGit(repoConfig.repoPath);
      const isRepo = await git.checkIsRepo();

      if (!isRepo) {
        throw new AppError('Repository not initialized. Please run a build first.', 400);
      }

      // Fetch latest
      await git.fetch();

      // Get all branches
      const branches = await git.branch(['-r']);

      const branchList = Object.keys(branches.branches)
        .filter((branch) => !branch.endsWith('/HEAD'))
        .map((branch) => {
          const branchName = branch.replace('origin/', '');
          return {
            name: branchName,
            isDefault: branchName === repoConfig.defaultBranch,
          };
        });

      res.json({ branches: branchList });
    } catch (error) {
      logger.error(`Failed to get branches for ${repoType}:`, error);
      throw new AppError('Failed to retrieve branches', 500);
    }
  })
);

// Get cleanup policies
router.get(
  '/cleanup-policies',
  asyncHandler(async (req: any, res: any) => {
    const prisma = getPrismaClient();

    const policies = await prisma.cleanupPolicy.findMany({
      orderBy: {
        createdAt: 'asc',
      },
    });

    res.json({ policies });
  })
);

// Create cleanup policy (admin only)
router.post(
  '/cleanup-policies',
  authenticate,
  authorize(UserRole.ADMIN),
  [
    body('policyName').notEmpty(),
    body('retentionDays').isInt({ min: 1, max: 365 }),
    body('retentionCount').isInt({ min: 1, max: 1000 }),
    body('cleanFailedTasks').isBoolean(),
    body('archiveBeforeDelete').isBoolean(),
  ],
  asyncHandler(async (req: AuthRequest, res: any) => {
    const {
      policyName,
      retentionDays,
      retentionCount,
      cleanFailedTasks,
      archiveBeforeDelete,
      archivePath,
      scheduleCron,
    } = req.body;

    const prisma = getPrismaClient();

    // Check if policy name already exists
    const existingPolicy = await prisma.cleanupPolicy.findUnique({
      where: { policyName },
    });

    if (existingPolicy) {
      throw new AppError('Policy with this name already exists', 400);
    }

    const policy = await prisma.cleanupPolicy.create({
      data: {
        policyName,
        retentionDays,
        retentionCount,
        cleanFailedTasks,
        archiveBeforeDelete,
        archivePath,
        scheduleCron,
      },
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user!.id,
        action: 'create_cleanup_policy',
        resourceType: 'cleanup_policy',
        resourceId: policy.id.toString(),
        result: 'success',
      },
    });

    logger.info(`Cleanup policy '${policyName}' created by ${req.user!.username}`);

    res.status(201).json({
      message: 'Cleanup policy created',
      policy,
    });
  })
);

// Toggle cleanup policy (admin only)
router.put(
  '/cleanup-policies/:id/toggle',
  authenticate,
  authorize(UserRole.ADMIN),
  param('id').isInt(),
  asyncHandler(async (req: AuthRequest, res: any) => {
    const policyId = parseInt(req.params.id);

    const prisma = getPrismaClient();

    const policy = await prisma.cleanupPolicy.findUnique({
      where: { id: policyId },
    });

    if (!policy) {
      throw new AppError('Policy not found', 404);
    }

    const updatedPolicy = await prisma.cleanupPolicy.update({
      where: { id: policyId },
      data: {
        isActive: !policy.isActive,
      },
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user!.id,
        action: 'toggle_cleanup_policy',
        resourceType: 'cleanup_policy',
        resourceId: policyId.toString(),
        payload: { isActive: updatedPolicy.isActive },
        result: 'success',
      },
    });

    const action = updatedPolicy.isActive ? 'activated' : 'deactivated';
    logger.info(`Cleanup policy ${policyId} ${action} by ${req.user!.username}`);

    res.json({
      message: `Policy ${action} successfully`,
      policy: updatedPolicy,
    });
  })
);

// Delete cleanup policy (admin only)
router.delete(
  '/cleanup-policies/:id',
  authenticate,
  authorize(UserRole.ADMIN),
  param('id').isInt(),
  asyncHandler(async (req: AuthRequest, res: any) => {
    const policyId = parseInt(req.params.id);

    const prisma = getPrismaClient();

    const policy = await prisma.cleanupPolicy.findUnique({
      where: { id: policyId },
    });

    if (!policy) {
      throw new AppError('Policy not found', 404);
    }

    await prisma.cleanupPolicy.delete({
      where: { id: policyId },
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user!.id,
        action: 'delete_cleanup_policy',
        resourceType: 'cleanup_policy',
        resourceId: policyId.toString(),
        result: 'success',
      },
    });

    logger.info(`Cleanup policy ${policyId} deleted by ${req.user!.username}`);

    res.json({ message: 'Policy deleted successfully' });
  })
);

// Get system configuration (current settings)
router.get(
  '/system',
  authenticate,
  asyncHandler(async (req: AuthRequest, res: any) => {
    res.json({
      config: {
        unityEditorPath: config.UNITY_EDITOR_PATH,
        flutterSdkPath: config.FLUTTER_SDK_PATH,
        buildTimeout: config.BUILD_TIMEOUT,
        maxConcurrentBuilds: config.MAX_CONCURRENT_BUILDS,
        artifactsDir: config.ARTIFACTS_DIR,
        logsDir: config.LOGS_DIR,
      },
    });
  })
);

export default router;