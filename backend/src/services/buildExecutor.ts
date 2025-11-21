import { exec, spawn } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import fs from 'fs/promises';
import crypto from 'crypto';
import simpleGit, { SimpleGit } from 'simple-git';
import { TaskStatus, TaskStage } from '@prisma/client';
import { getPrismaClient } from './database';
import { TaskLock, TaskQueue } from './redis';
import { config } from '../config';
import { logger } from '../utils/logger';
import { io } from '../server';

const execAsync = promisify(exec);

export class BuildExecutor {
  private git: SimpleGit;

  constructor() {
    this.git = simpleGit();
  }

  async execute(taskId: number): Promise<void> {
    try {
      // Try to acquire lock
      const lockAcquired = await TaskLock.acquire(taskId);
      if (!lockAcquired) {
        // Add to queue if lock not acquired
        await TaskQueue.enqueue(taskId);
        logger.info(`Task ${taskId} added to queue (lock not available)`);
        return;
      }

      // Start execution
      await this.executeTask(taskId);
    } catch (error) {
      logger.error(`Task ${taskId} execution failed:`, error);
      await this.updateTaskStatus(taskId, TaskStatus.FAILED, {
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
      });
    } finally {
      await TaskLock.release(taskId);
      // Process next task in queue
      this.processNextInQueue();
    }
  }

  private async processNextInQueue(): Promise<void> {
    const nextTaskId = await TaskQueue.dequeue();
    if (nextTaskId) {
      logger.info(`Processing next task from queue: ${nextTaskId}`);
      this.execute(nextTaskId).catch(error => {
        logger.error(`Failed to process queued task ${nextTaskId}:`, error);
      });
    }
  }

  private async executeTask(taskId: number): Promise<void> {
    const prisma = getPrismaClient();

    const task = await prisma.task.findUnique({
      where: { id: taskId },
    });

    if (!task) {
      throw new Error(`Task ${taskId} not found`);
    }

    logger.info(`Starting execution of task ${taskId}`);

    // Update status to RUNNING
    await this.updateTaskStatus(taskId, TaskStatus.RUNNING, {
      startedAt: new Date(),
      progress: 0,
      progressMessage: 'Starting build process',
    });

    // Execute build stages
    let success = true;

    // Stage 1: Unity Fetch
    if (success) {
      success = await this.executeUnityFetch(taskId, task.unityBranch);
    }

    // Stage 2: Unity Build
    if (success) {
      success = await this.executeUnityBuild(taskId, task.unityArgs as any);
    }

    // Stage 3: Flutter Fetch
    if (success) {
      success = await this.executeFlutterFetch(taskId, task.flutterBranch);
    }

    // Stage 4: Flutter Build
    if (success) {
      success = await this.executeFlutterBuild(taskId, task.flutterArgs as any);
    }

    // Stage 5: Save Artifact
    if (success) {
      success = await this.saveArtifact(taskId);
    }

    // Update final status
    const finalStatus = success ? TaskStatus.SUCCESS : TaskStatus.FAILED;
    await this.updateTaskStatus(taskId, finalStatus, {
      completedAt: new Date(),
      progress: 100,
      progressMessage: success ? 'Build completed successfully' : 'Build failed',
    });

    logger.info(`Task ${taskId} completed with status: ${finalStatus}`);
  }

  private async executeUnityFetch(taskId: number, branch: string): Promise<boolean> {
    try {
      await this.updateTaskStatus(taskId, TaskStatus.RUNNING, {
        currentStage: TaskStage.UNITY_FETCH,
        progress: 10,
        progressMessage: 'Fetching Unity repository',
      });

      const startTime = Date.now();
      const repoPath = config.UNITY_REPO_PATH;

      // Ensure directory exists
      await fs.mkdir(repoPath, { recursive: true });

      // Clone or update repository
      const git = simpleGit(repoPath);
      const isRepo = await git.checkIsRepo();

      if (!isRepo) {
        // Clone repository
        logger.info(`Cloning Unity repository to ${repoPath}`);
        await simpleGit().clone(config.UNITY_REPO_URL, repoPath, ['--branch', branch]);
        this.emitLog(taskId, `Cloned Unity repository to ${repoPath}`, 'unity_fetch');
      } else {
        // Update repository
        logger.info(`Updating Unity repository at ${repoPath}`);
        await git.fetch();
        await git.checkout(branch);
        await git.pull();
        this.emitLog(taskId, `Updated Unity repository to branch ${branch}`, 'unity_fetch');
      }

      // Get commit hash
      const commit = await git.revparse(['HEAD']);

      // Update task
      const prisma = getPrismaClient();
      await prisma.task.update({
        where: { id: taskId },
        data: {
          unityCommit: commit,
          unityFetchDuration: (Date.now() - startTime) / 1000,
        },
      });

      // Log stage completion
      await this.logStage(taskId, TaskStage.UNITY_FETCH, true, {
        logContent: `Successfully fetched Unity branch ${branch}`,
        duration: Date.now() - startTime,
      });

      return true;
    } catch (error) {
      logger.error(`Unity fetch failed for task ${taskId}:`, error);
      await this.logStage(taskId, TaskStage.UNITY_FETCH, false, {
        errorMessage: error instanceof Error ? error.message : 'Unity fetch failed',
      });
      return false;
    }
  }

  private async executeUnityBuild(taskId: number, args: Record<string, any>): Promise<boolean> {
    try {
      await this.updateTaskStatus(taskId, TaskStatus.RUNNING, {
        currentStage: TaskStage.UNITY_BUILD,
        progress: 30,
        progressMessage: 'Building Unity project',
      });

      const startTime = Date.now();

      // Build Unity command
      const unityCmd = [
        config.UNITY_EDITOR_PATH,
        '-batchmode',
        '-quit',
        '-projectPath',
        config.UNITY_REPO_PATH,
        '-executeMethod',
        'BuildScript.ExportToFlutter',
      ];

      // Add custom arguments
      for (const [key, value] of Object.entries(args)) {
        unityCmd.push(`-${key}`, String(value));
      }

      // Execute Unity build
      const unityProcess = spawn(unityCmd[0], unityCmd.slice(1));

      unityProcess.stdout.on('data', (data) => {
        const log = data.toString();
        logger.info(`Unity build output: ${log}`);
        this.emitLog(taskId, log, 'unity_build');
      });

      unityProcess.stderr.on('data', (data) => {
        const log = data.toString();
        logger.error(`Unity build error: ${log}`);
        this.emitLog(taskId, log, 'unity_build');
      });

      const exitCode = await new Promise<number>((resolve) => {
        unityProcess.on('exit', resolve);
      });

      if (exitCode !== 0) {
        throw new Error(`Unity build failed with exit code ${exitCode}`);
      }

      // Update task
      const prisma = getPrismaClient();
      await prisma.task.update({
        where: { id: taskId },
        data: {
          unityBuildDuration: (Date.now() - startTime) / 1000,
        },
      });

      await this.logStage(taskId, TaskStage.UNITY_BUILD, true, {
        logContent: 'Unity build completed successfully',
        duration: Date.now() - startTime,
      });

      return true;
    } catch (error) {
      logger.error(`Unity build failed for task ${taskId}:`, error);
      await this.logStage(taskId, TaskStage.UNITY_BUILD, false, {
        errorMessage: error instanceof Error ? error.message : 'Unity build failed',
      });
      return false;
    }
  }

  private async executeFlutterFetch(taskId: number, branch: string): Promise<boolean> {
    try {
      await this.updateTaskStatus(taskId, TaskStatus.RUNNING, {
        currentStage: TaskStage.FLUTTER_FETCH,
        progress: 50,
        progressMessage: 'Fetching Flutter repository',
      });

      const startTime = Date.now();
      const repoPath = config.FLUTTER_REPO_PATH;

      // Ensure directory exists
      await fs.mkdir(repoPath, { recursive: true });

      // Clone or update repository
      const git = simpleGit(repoPath);
      const isRepo = await git.checkIsRepo();

      if (!isRepo) {
        // Clone repository
        logger.info(`Cloning Flutter repository to ${repoPath}`);
        await simpleGit().clone(config.FLUTTER_REPO_URL, repoPath, ['--branch', branch]);
        this.emitLog(taskId, `Cloned Flutter repository to ${repoPath}`, 'flutter_fetch');
      } else {
        // Update repository
        logger.info(`Updating Flutter repository at ${repoPath}`);
        await git.fetch();
        await git.checkout(branch);
        await git.pull();
        this.emitLog(taskId, `Updated Flutter repository to branch ${branch}`, 'flutter_fetch');
      }

      // Get commit hash
      const commit = await git.revparse(['HEAD']);

      // Update task
      const prisma = getPrismaClient();
      await prisma.task.update({
        where: { id: taskId },
        data: {
          flutterCommit: commit,
          flutterFetchDuration: (Date.now() - startTime) / 1000,
        },
      });

      await this.logStage(taskId, TaskStage.FLUTTER_FETCH, true, {
        logContent: `Successfully fetched Flutter branch ${branch}`,
        duration: Date.now() - startTime,
      });

      return true;
    } catch (error) {
      logger.error(`Flutter fetch failed for task ${taskId}:`, error);
      await this.logStage(taskId, TaskStage.FLUTTER_FETCH, false, {
        errorMessage: error instanceof Error ? error.message : 'Flutter fetch failed',
      });
      return false;
    }
  }

  private async executeFlutterBuild(taskId: number, args: Record<string, any>): Promise<boolean> {
    try {
      await this.updateTaskStatus(taskId, TaskStatus.RUNNING, {
        currentStage: TaskStage.FLUTTER_BUILD,
        progress: 70,
        progressMessage: 'Building Flutter APK',
      });

      const startTime = Date.now();

      // Change to Flutter project directory
      process.chdir(config.FLUTTER_REPO_PATH);

      // Run flutter pub get
      await execAsync(`${config.FLUTTER_SDK_PATH}/bin/flutter pub get`);
      this.emitLog(taskId, 'Flutter dependencies installed', 'flutter_build');

      // Build Flutter APK
      let buildCmd = `${config.FLUTTER_SDK_PATH}/bin/flutter build apk --release`;

      // Add custom arguments
      for (const [key, value] of Object.entries(args)) {
        buildCmd += ` --${key}=${value}`;
      }

      const flutterProcess = spawn('sh', ['-c', buildCmd]);

      flutterProcess.stdout.on('data', (data) => {
        const log = data.toString();
        logger.info(`Flutter build output: ${log}`);
        this.emitLog(taskId, log, 'flutter_build');
      });

      flutterProcess.stderr.on('data', (data) => {
        const log = data.toString();
        logger.error(`Flutter build error: ${log}`);
        this.emitLog(taskId, log, 'flutter_build');
      });

      const exitCode = await new Promise<number>((resolve) => {
        flutterProcess.on('exit', resolve);
      });

      if (exitCode !== 0) {
        throw new Error(`Flutter build failed with exit code ${exitCode}`);
      }

      // Update task
      const prisma = getPrismaClient();
      await prisma.task.update({
        where: { id: taskId },
        data: {
          flutterBuildDuration: (Date.now() - startTime) / 1000,
        },
      });

      await this.logStage(taskId, TaskStage.FLUTTER_BUILD, true, {
        logContent: 'Flutter build completed successfully',
        duration: Date.now() - startTime,
      });

      return true;
    } catch (error) {
      logger.error(`Flutter build failed for task ${taskId}:`, error);
      await this.logStage(taskId, TaskStage.FLUTTER_BUILD, false, {
        errorMessage: error instanceof Error ? error.message : 'Flutter build failed',
      });
      return false;
    }
  }

  private async saveArtifact(taskId: number): Promise<boolean> {
    try {
      await this.updateTaskStatus(taskId, TaskStatus.RUNNING, {
        currentStage: TaskStage.ARTIFACT_SAVE,
        progress: 90,
        progressMessage: 'Saving build artifact',
      });

      const prisma = getPrismaClient();
      const task = await prisma.task.findUnique({
        where: { id: taskId },
      });

      if (!task) {
        throw new Error('Task not found');
      }

      // APK file path
      const apkSource = path.join(
        config.FLUTTER_REPO_PATH,
        'build/app/outputs/flutter-apk/app-release.apk'
      );

      // Check if APK exists
      await fs.access(apkSource);

      // Generate file name
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `${timestamp}_${task.taskUuid}.apk`;
      const artifactPath = path.join(config.ARTIFACTS_DIR, fileName);

      // Ensure artifacts directory exists
      await fs.mkdir(config.ARTIFACTS_DIR, { recursive: true });

      // Copy APK
      await fs.copyFile(apkSource, artifactPath);

      // Calculate checksum
      const fileBuffer = await fs.readFile(artifactPath);
      const checksum = crypto.createHash('sha256').update(fileBuffer).digest('hex');

      // Get file size
      const stats = await fs.stat(artifactPath);

      // Create artifact record
      const artifact = await prisma.artifact.create({
        data: {
          taskId,
          fileName,
          filePath: artifactPath,
          fileSize: stats.size,
          checksum,
          downloadUrl: `/artifacts/${fileName}`,
        },
      });

      logger.info(`Artifact saved for task ${taskId}: ${fileName}`);

      await this.logStage(taskId, TaskStage.ARTIFACT_SAVE, true, {
        logContent: `Artifact saved: ${fileName}`,
      });

      return true;
    } catch (error) {
      logger.error(`Failed to save artifact for task ${taskId}:`, error);
      await this.logStage(taskId, TaskStage.ARTIFACT_SAVE, false, {
        errorMessage: error instanceof Error ? error.message : 'Failed to save artifact',
      });
      return false;
    }
  }

  private async updateTaskStatus(
    taskId: number,
    status: TaskStatus,
    data: any = {}
  ): Promise<void> {
    const prisma = getPrismaClient();

    const task = await prisma.task.update({
      where: { id: taskId },
      data: {
        status,
        ...data,
      },
    });

    // Emit WebSocket event
    io.emit('task_update', {
      taskId: task.taskUuid,
      status: status.toLowerCase(),
      progress: data.progress,
      message: data.progressMessage,
    });
  }

  private async logStage(
    taskId: number,
    stage: TaskStage,
    success: boolean,
    data: any = {}
  ): Promise<void> {
    const prisma = getPrismaClient();

    await prisma.stageLog.create({
      data: {
        taskId,
        stage,
        success,
        startedAt: new Date(Date.now() - (data.duration || 0)),
        completedAt: new Date(),
        logContent: data.logContent,
        errorMessage: data.errorMessage,
      },
    });
  }

  private emitLog(taskId: number, log: string, stage: string): void {
    const prisma = getPrismaClient();

    // Get task UUID
    prisma.task
      .findUnique({
        where: { id: taskId },
        select: { taskUuid: true },
      })
      .then((task) => {
        if (task) {
          io.to(`logs_${task.taskUuid}`).emit('log_stream', {
            taskId: task.taskUuid,
            log,
            stage,
            timestamp: new Date().toISOString(),
          });
        }
      })
      .catch((error) => {
        logger.error('Failed to emit log:', error);
      });
  }
}