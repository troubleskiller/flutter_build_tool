import Redis from 'ioredis';
import { config } from '../config';
import { logger } from '../utils/logger';

let redisClient: Redis | null = null;

export function getRedisClient(): Redis {
  if (!redisClient) {
    redisClient = new Redis(config.REDIS_URL, {
      maxRetriesPerRequest: 3,
      retryStrategy: (times: number) => {
        const delay = Math.min(times * 50, 2000);
        return delay;
      },
    });

    redisClient.on('connect', () => {
      logger.info('Redis connected successfully');
    });

    redisClient.on('error', (error) => {
      logger.error('Redis connection error:', error);
    });

    redisClient.on('close', () => {
      logger.warn('Redis connection closed');
    });
  }

  return redisClient;
}

export async function initializeRedis(): Promise<void> {
  const client = getRedisClient();
  try {
    await client.ping();
    logger.info('Redis connection verified');
  } catch (error) {
    logger.error('Failed to connect to Redis:', error);
    throw error;
  }
}

export async function closeRedisConnection(): Promise<void> {
  if (redisClient) {
    await redisClient.quit();
    redisClient = null;
    logger.info('Redis connection closed');
  }
}

// Task lock management
export class TaskLock {
  private static readonly LOCK_KEY = 'build_task_lock';
  private static readonly LOCK_TIMEOUT = 3600; // 1 hour in seconds

  static async acquire(taskId: number): Promise<boolean> {
    const client = getRedisClient();
    const result = await client.set(
      this.LOCK_KEY,
      taskId.toString(),
      'EX',
      this.LOCK_TIMEOUT,
      'NX'
    );
    return result === 'OK';
  }

  static async release(taskId: number): Promise<boolean> {
    const client = getRedisClient();
    const currentLock = await client.get(this.LOCK_KEY);

    if (currentLock === taskId.toString()) {
      await client.del(this.LOCK_KEY);
      return true;
    }

    return false;
  }

  static async getCurrentLock(): Promise<number | null> {
    const client = getRedisClient();
    const lock = await client.get(this.LOCK_KEY);
    return lock ? parseInt(lock, 10) : null;
  }

  static async isLocked(): Promise<boolean> {
    const lock = await this.getCurrentLock();
    return lock !== null;
  }
}

// Task queue management
export class TaskQueue {
  private static readonly QUEUE_KEY = 'build_task_queue';

  static async enqueue(taskId: number): Promise<void> {
    const client = getRedisClient();
    await client.rpush(this.QUEUE_KEY, taskId.toString());
    logger.info(`Task ${taskId} added to queue`);
  }

  static async dequeue(): Promise<number | null> {
    const client = getRedisClient();
    const taskId = await client.lpop(this.QUEUE_KEY);
    return taskId ? parseInt(taskId, 10) : null;
  }

  static async getPosition(taskId: number): Promise<number> {
    const client = getRedisClient();
    const queue = await client.lrange(this.QUEUE_KEY, 0, -1);

    const position = queue.findIndex(id => id === taskId.toString());
    return position === -1 ? -1 : position + 1;
  }

  static async getLength(): Promise<number> {
    const client = getRedisClient();
    return await client.llen(this.QUEUE_KEY);
  }

  static async remove(taskId: number): Promise<void> {
    const client = getRedisClient();
    await client.lrem(this.QUEUE_KEY, 0, taskId.toString());
  }

  static async getAll(): Promise<number[]> {
    const client = getRedisClient();
    const queue = await client.lrange(this.QUEUE_KEY, 0, -1);
    return queue.map(id => parseInt(id, 10));
  }
}