import { PrismaClient, UserRole } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { config } from '../config';

const prisma = new PrismaClient();

async function main() {
  console.log('Starting database seed...');

  // Create admin user
  const adminPassword = await bcrypt.hash('admin123', config.BCRYPT_ROUNDS);
  const admin = await prisma.user.upsert({
    where: { username: 'admin' },
    update: {},
    create: {
      username: 'admin',
      email: 'admin@example.com',
      hashedPassword: adminPassword,
      role: UserRole.ADMIN,
      isActive: true,
    },
  });
  console.log('Admin user created:', admin.username);

  // Create test user
  const testPassword = await bcrypt.hash('test123', config.BCRYPT_ROUNDS);
  const testUser = await prisma.user.upsert({
    where: { username: 'test' },
    update: {},
    create: {
      username: 'test',
      email: 'test@example.com',
      hashedPassword: testPassword,
      role: UserRole.USER,
      isActive: true,
    },
  });
  console.log('Test user created:', testUser.username);

  // Create default cleanup policy
  const defaultPolicy = await prisma.cleanupPolicy.upsert({
    where: { policyName: 'default' },
    update: {},
    create: {
      policyName: 'default',
      retentionDays: 30,
      retentionCount: 100,
      cleanFailedTasks: false,
      archiveBeforeDelete: true,
      isActive: true,
    },
  });
  console.log('Default cleanup policy created:', defaultPolicy.policyName);

  // Create Unity repo config (optional)
  if (config.UNITY_REPO_URL) {
    const unityConfig = await prisma.repoConfig.upsert({
      where: { repoType: 'unity' },
      update: {},
      create: {
        repoType: 'unity',
        repoUrl: config.UNITY_REPO_URL,
        repoPath: config.UNITY_REPO_PATH,
        defaultBranch: 'main',
        authType: 'https',
      },
    });
    console.log('Unity repository configuration created');
  }

  // Create Flutter repo config (optional)
  if (config.FLUTTER_REPO_URL) {
    const flutterConfig = await prisma.repoConfig.upsert({
      where: { repoType: 'flutter' },
      update: {},
      create: {
        repoType: 'flutter',
        repoUrl: config.FLUTTER_REPO_URL,
        repoPath: config.FLUTTER_REPO_PATH,
        defaultBranch: 'main',
        authType: 'https',
      },
    });
    console.log('Flutter repository configuration created');
  }

  console.log('Database seed completed!');
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error('Seed error:', e);
    await prisma.$disconnect();
    process.exit(1);
  });