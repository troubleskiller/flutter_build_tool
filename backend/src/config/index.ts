import dotenv from 'dotenv';
import path from 'path';

dotenv.config();

export const config = {
  // App
  NODE_ENV: process.env.NODE_ENV || 'development',
  PORT: parseInt(process.env.PORT || '8000', 10),

  // Security
  JWT_SECRET: process.env.JWT_SECRET || 'your-secret-key-change-in-production',
  JWT_EXPIRE: process.env.JWT_EXPIRE || '7d',
  BCRYPT_ROUNDS: 10,

  // Database
  DATABASE_URL: process.env.DATABASE_URL || 'postgresql://postgres:password@localhost:5432/flutter_unity_build',

  // Redis
  REDIS_URL: process.env.REDIS_URL || 'redis://localhost:6379',

  // Frontend
  FRONTEND_URL: process.env.FRONTEND_URL || 'http://localhost:3000',

  // Unity Configuration
  UNITY_EDITOR_PATH: process.env.UNITY_EDITOR_PATH || '/Applications/Unity/Hub/Editor/2022.3.10f1/Unity.app/Contents/MacOS/Unity',
  UNITY_REPO_PATH: process.env.UNITY_REPO_PATH || '/tmp/unity_repo',
  UNITY_REPO_URL: process.env.UNITY_REPO_URL || '',

  // Flutter Configuration
  FLUTTER_SDK_PATH: process.env.FLUTTER_SDK_PATH || '/usr/local/flutter',
  FLUTTER_REPO_PATH: process.env.FLUTTER_REPO_PATH || '/tmp/flutter_repo',
  FLUTTER_REPO_URL: process.env.FLUTTER_REPO_URL || '',

  // Build Configuration
  BUILD_TIMEOUT: parseInt(process.env.BUILD_TIMEOUT || '3600000', 10), // 1 hour in ms
  MAX_CONCURRENT_BUILDS: 1,

  // Paths
  ARTIFACTS_DIR: path.join(__dirname, '../../../artifacts'),
  LOGS_DIR: path.join(__dirname, '../../../logs'),

  // Cleanup
  MAX_ARTIFACT_AGE_DAYS: parseInt(process.env.MAX_ARTIFACT_AGE_DAYS || '30', 10),
  MAX_ARTIFACT_COUNT: parseInt(process.env.MAX_ARTIFACT_COUNT || '100', 10),

  // Email (Optional)
  SMTP_HOST: process.env.SMTP_HOST,
  SMTP_PORT: parseInt(process.env.SMTP_PORT || '587', 10),
  SMTP_USER: process.env.SMTP_USER,
  SMTP_PASSWORD: process.env.SMTP_PASSWORD,

  // Webhook (Optional)
  WEBHOOK_URL: process.env.WEBHOOK_URL,
};