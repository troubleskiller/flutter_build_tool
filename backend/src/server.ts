import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
import path from 'path';
import 'express-async-errors';

import { errorHandler } from './middlewares/error';
import { logger } from './utils/logger';
import { initializeRedis } from './services/redis';
import { initializeDatabase } from './services/database';

// Routes
import authRoutes from './routes/auth';
import taskRoutes from './routes/tasks';
import artifactRoutes from './routes/artifacts';
import statisticsRoutes from './routes/statistics';
import configRoutes from './routes/config';

// Load environment variables
dotenv.config();

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: process.env.FRONTEND_URL || 'http://localhost:3000',
    credentials: true
  }
});

// Middleware
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files for artifacts
app.use('/artifacts', express.static(path.join(__dirname, '../../artifacts')));

// API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/tasks', taskRoutes);
app.use('/api/v1/artifacts', artifactRoutes);
app.use('/api/v1/statistics', statisticsRoutes);
app.use('/api/v1/config', configRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'Flutter Unity Build Tool API',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Flutter Unity Build Tool API',
    version: '1.0.0',
    docs: '/api/docs'
  });
});

// WebSocket connection handling
io.on('connection', (socket) => {
  logger.info(`Client connected: ${socket.id}`);

  socket.on('join_task', (taskId: string) => {
    socket.join(`task_${taskId}`);
    logger.info(`Client ${socket.id} joined task_${taskId}`);
  });

  socket.on('leave_task', (taskId: string) => {
    socket.leave(`task_${taskId}`);
    logger.info(`Client ${socket.id} left task_${taskId}`);
  });

  socket.on('subscribe_logs', (taskId: string) => {
    socket.join(`logs_${taskId}`);
    logger.info(`Client ${socket.id} subscribed to logs_${taskId}`);
  });

  socket.on('disconnect', () => {
    logger.info(`Client disconnected: ${socket.id}`);
  });
});

// Export io for use in other modules
export { io };

// Error handling middleware (must be last)
app.use(errorHandler);

// Initialize services and start server
const PORT = process.env.PORT || 8000;

async function startServer() {
  try {
    // Initialize database
    await initializeDatabase();
    logger.info('Database connected successfully');

    // Initialize Redis
    await initializeRedis();
    logger.info('Redis connected successfully');

    // Start server
    httpServer.listen(PORT, () => {
      logger.info(`Server running on port ${PORT}`);
      logger.info(`API docs available at http://localhost:${PORT}/api/docs`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  httpServer.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  httpServer.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

// Start the server
startServer();