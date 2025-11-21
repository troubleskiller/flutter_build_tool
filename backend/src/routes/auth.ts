import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { body, validationResult } from 'express-validator';
import { config } from '../config';
import { getPrismaClient } from '../services/database';
import { AppError, asyncHandler } from '../middlewares/error';
import { authenticate, AuthRequest } from '../middlewares/auth';
import { logger } from '../utils/logger';

const router = Router();

// Validation middleware
const handleValidationErrors = (req: any, res: any, next: any) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    throw new AppError(`Validation error: ${errors.array()[0].msg}`, 400);
  }
  next();
};

// Register
router.post(
  '/register',
  [
    body('username')
      .isLength({ min: 3 })
      .withMessage('Username must be at least 3 characters')
      .matches(/^[a-zA-Z0-9_]+$/)
      .withMessage('Username can only contain letters, numbers, and underscores'),
    body('email').isEmail().withMessage('Invalid email address'),
    body('password')
      .isLength({ min: 6 })
      .withMessage('Password must be at least 6 characters'),
  ],
  handleValidationErrors,
  asyncHandler(async (req: any, res: any) => {
    const { username, email, password } = req.body;

    const prisma = getPrismaClient();

    // Check if user already exists
    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [{ username }, { email }],
      },
    });

    if (existingUser) {
      throw new AppError('Username or email already exists', 400);
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, config.BCRYPT_ROUNDS);

    // Create user
    const user = await prisma.user.create({
      data: {
        username,
        email,
        hashedPassword,
      },
      select: {
        id: true,
        username: true,
        email: true,
        role: true,
        createdAt: true,
      },
    });

    logger.info(`New user registered: ${username}`);

    res.status(201).json({
      message: 'User registered successfully',
      user,
    });
  })
);

// Login
router.post(
  '/login',
  [
    body('username').notEmpty().withMessage('Username is required'),
    body('password').notEmpty().withMessage('Password is required'),
  ],
  handleValidationErrors,
  asyncHandler(async (req: any, res: any) => {
    const { username, password } = req.body;

    const prisma = getPrismaClient();

    // Find user
    const user = await prisma.user.findUnique({
      where: { username },
    });

    if (!user || !user.isActive) {
      throw new AppError('Invalid credentials', 401);
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.hashedPassword);

    if (!isPasswordValid) {
      throw new AppError('Invalid credentials', 401);
    }

    // Update last login
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLogin: new Date() },
    });

    // Generate token
    const token = jwt.sign(
      {
        userId: user.id,
        username: user.username,
        role: user.role,
      },
      config.JWT_SECRET,
      { expiresIn: config.JWT_EXPIRE }
    );

    logger.info(`User logged in: ${username}`);

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
      },
    });
  })
);

// Get current user
router.get(
  '/me',
  authenticate,
  asyncHandler(async (req: AuthRequest, res: any) => {
    const prisma = getPrismaClient();

    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: {
        id: true,
        username: true,
        email: true,
        role: true,
        createdAt: true,
        lastLogin: true,
      },
    });

    res.json({ user });
  })
);

// Change password
router.post(
  '/change-password',
  authenticate,
  [
    body('currentPassword').notEmpty().withMessage('Current password is required'),
    body('newPassword')
      .isLength({ min: 6 })
      .withMessage('New password must be at least 6 characters'),
  ],
  handleValidationErrors,
  asyncHandler(async (req: AuthRequest, res: any) => {
    const { currentPassword, newPassword } = req.body;

    const prisma = getPrismaClient();

    // Get user with password
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
    });

    if (!user) {
      throw new AppError('User not found', 404);
    }

    // Verify current password
    const isPasswordValid = await bcrypt.compare(currentPassword, user.hashedPassword);

    if (!isPasswordValid) {
      throw new AppError('Current password is incorrect', 400);
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, config.BCRYPT_ROUNDS);

    // Update password
    await prisma.user.update({
      where: { id: user.id },
      data: { hashedPassword },
    });

    logger.info(`Password changed for user: ${user.username}`);

    res.json({ message: 'Password changed successfully' });
  })
);

// Logout (optional - mainly for client-side token removal)
router.post('/logout', authenticate, (req: AuthRequest, res: any) => {
  logger.info(`User logged out: ${req.user?.username}`);
  res.json({ message: 'Logged out successfully' });
});

export default router;