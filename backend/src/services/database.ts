import { PrismaClient } from '@prisma/client';
import { logger } from '../utils/logger';

let prisma: PrismaClient;

export function getPrismaClient(): PrismaClient {
  if (!prisma) {
    prisma = new PrismaClient({
      log: process.env.NODE_ENV === 'development'
        ? ['query', 'info', 'warn', 'error']
        : ['error'],
    });
  }
  return prisma;
}

export async function initializeDatabase(): Promise<void> {
  const client = getPrismaClient();
  try {
    await client.$connect();
    logger.info('Database connection established');
  } catch (error) {
    logger.error('Failed to connect to database:', error);
    throw error;
  }
}

export async function closeDatabaseConnection(): Promise<void> {
  if (prisma) {
    await prisma.$disconnect();
    logger.info('Database connection closed');
  }
}

// Export prisma client
export { prisma };