// Memory cache service for lightweight mode (no Redis required)
import { logger } from '../utils/logger';

interface CacheItem {
  value: any;
  expireAt?: number;
}

class MemoryCache {
  private cache: Map<string, CacheItem> = new Map();
  private locks: Map<string, number> = new Map();
  private queues: Map<string, string[]> = new Map();

  constructor() {
    // Clean up expired items every minute
    setInterval(() => this.cleanupExpired(), 60000);
  }

  // Basic cache operations
  async set(key: string, value: any, ttlSeconds?: number): Promise<void> {
    const item: CacheItem = {
      value,
      expireAt: ttlSeconds ? Date.now() + (ttlSeconds * 1000) : undefined
    };
    this.cache.set(key, item);
  }

  async get(key: string): Promise<any> {
    const item = this.cache.get(key);
    if (!item) return null;

    if (item.expireAt && item.expireAt < Date.now()) {
      this.cache.delete(key);
      return null;
    }

    return item.value;
  }

  async del(key: string): Promise<void> {
    this.cache.delete(key);
  }

  async exists(key: string): Promise<boolean> {
    return this.cache.has(key);
  }

  // Lock operations (simulating Redis locks)
  async acquireLock(key: string, taskId: number, ttlSeconds: number = 3600): Promise<boolean> {
    const currentLock = this.locks.get(key);

    if (currentLock && this.cache.has(`lock:${key}`)) {
      // Lock exists and hasn't expired
      return false;
    }

    this.locks.set(key, taskId);
    await this.set(`lock:${key}`, taskId, ttlSeconds);
    logger.info(`Lock acquired: ${key} by task ${taskId}`);
    return true;
  }

  async releaseLock(key: string, taskId: number): Promise<boolean> {
    const currentLock = this.locks.get(key);

    if (currentLock === taskId) {
      this.locks.delete(key);
      await this.del(`lock:${key}`);
      logger.info(`Lock released: ${key} by task ${taskId}`);
      return true;
    }

    return false;
  }

  async getCurrentLock(key: string): Promise<number | null> {
    const lock = await this.get(`lock:${key}`);
    return lock ? parseInt(lock, 10) : null;
  }

  async isLocked(key: string): Promise<boolean> {
    const lock = await this.getCurrentLock(key);
    return lock !== null;
  }

  // Queue operations (simulating Redis lists)
  async enqueue(queueName: string, value: string): Promise<void> {
    if (!this.queues.has(queueName)) {
      this.queues.set(queueName, []);
    }
    this.queues.get(queueName)!.push(value);
    logger.info(`Enqueued ${value} to ${queueName}`);
  }

  async dequeue(queueName: string): Promise<string | null> {
    const queue = this.queues.get(queueName);
    if (!queue || queue.length === 0) {
      return null;
    }
    const value = queue.shift();
    logger.info(`Dequeued ${value} from ${queueName}`);
    return value || null;
  }

  async getQueueLength(queueName: string): Promise<number> {
    const queue = this.queues.get(queueName);
    return queue ? queue.length : 0;
  }

  async getQueuePosition(queueName: string, value: string): Promise<number> {
    const queue = this.queues.get(queueName);
    if (!queue) return -1;
    const position = queue.indexOf(value);
    return position === -1 ? -1 : position + 1;
  }

  async removeFromQueue(queueName: string, value: string): Promise<void> {
    const queue = this.queues.get(queueName);
    if (queue) {
      const index = queue.indexOf(value);
      if (index > -1) {
        queue.splice(index, 1);
        logger.info(`Removed ${value} from ${queueName}`);
      }
    }
  }

  async getQueue(queueName: string): Promise<string[]> {
    return this.queues.get(queueName) || [];
  }

  // Cleanup expired items
  private cleanupExpired(): void {
    const now = Date.now();
    let cleaned = 0;

    for (const [key, item] of this.cache.entries()) {
      if (item.expireAt && item.expireAt < now) {
        this.cache.delete(key);
        cleaned++;
      }
    }

    if (cleaned > 0) {
      logger.debug(`Cleaned up ${cleaned} expired cache items`);
    }
  }

  // Clear all data (for testing)
  clear(): void {
    this.cache.clear();
    this.locks.clear();
    this.queues.clear();
  }
}

// Singleton instance
let memoryCache: MemoryCache | null = null;

export function getMemoryCache(): MemoryCache {
  if (!memoryCache) {
    memoryCache = new MemoryCache();
    logger.info('Memory cache initialized (lightweight mode)');
  }
  return memoryCache;
}

// Task lock management using memory cache
export class MemoryTaskLock {
  private static readonly LOCK_KEY = 'build_task_lock';
  private static readonly LOCK_TIMEOUT = 3600; // 1 hour in seconds
  private cache = getMemoryCache();

  async acquire(taskId: number): Promise<boolean> {
    return await this.cache.acquireLock(this.constructor.LOCK_KEY, taskId, this.constructor.LOCK_TIMEOUT);
  }

  async release(taskId: number): Promise<boolean> {
    return await this.cache.releaseLock(this.constructor.LOCK_KEY, taskId);
  }

  async getCurrentLock(): Promise<number | null> {
    return await this.cache.getCurrentLock(this.constructor.LOCK_KEY);
  }

  async isLocked(): Promise<boolean> {
    return await this.cache.isLocked(this.constructor.LOCK_KEY);
  }
}

// Task queue management using memory cache
export class MemoryTaskQueue {
  private static readonly QUEUE_KEY = 'build_task_queue';
  private cache = getMemoryCache();

  async enqueue(taskId: number): Promise<void> {
    await this.cache.enqueue(this.constructor.QUEUE_KEY, taskId.toString());
  }

  async dequeue(): Promise<number | null> {
    const taskId = await this.cache.dequeue(this.constructor.QUEUE_KEY);
    return taskId ? parseInt(taskId, 10) : null;
  }

  async getPosition(taskId: number): Promise<number> {
    return await this.cache.getQueuePosition(this.constructor.QUEUE_KEY, taskId.toString());
  }

  async getLength(): Promise<number> {
    return await this.cache.getQueueLength(this.constructor.QUEUE_KEY);
  }

  async remove(taskId: number): Promise<void> {
    await this.cache.removeFromQueue(this.constructor.QUEUE_KEY, taskId.toString());
  }

  async getAll(): Promise<number[]> {
    const queue = await this.cache.getQueue(this.constructor.QUEUE_KEY);
    return queue.map(id => parseInt(id, 10));
  }
}