-- Database initialization script
-- This runs when PostgreSQL container is first created

-- Create database if not exists (backup)
SELECT 'CREATE DATABASE flutter_unity_build'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'flutter_unity_build')\gexec

-- Connect to the database
\c flutter_unity_build;

-- Create extensions if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set default timezone
SET timezone = 'UTC';

-- Create initial admin user (password will be updated by the app)
-- This is just a placeholder that will be replaced when the app starts
-- Default password: admin123
INSERT INTO users (username, email, "hashedPassword", role, "isActive", "createdAt")
VALUES ('admin', 'admin@example.com', '$2a$10$XQZ7V9z7z7z7z7z7z7z7zOhashed', 'ADMIN', true, NOW())
ON CONFLICT (username) DO NOTHING;

-- Create default repository configurations
INSERT INTO repo_configs ("repoType", "repoUrl", "repoPath", "defaultBranch", "updatedAt")
VALUES
  ('unity', '', '/repos/unity', 'main', NOW()),
  ('flutter', '', '/repos/flutter', 'main', NOW())
ON CONFLICT ("repoType") DO NOTHING;

-- Create default cleanup policy
INSERT INTO cleanup_policies (
  "policyName",
  "isActive",
  "retentionDays",
  "retentionCount",
  "cleanFailedTasks",
  "archiveBeforeDelete",
  "createdAt",
  "updatedAt"
)
VALUES (
  'default',
  true,
  30,
  100,
  false,
  true,
  NOW(),
  NOW()
)
ON CONFLICT ("policyName") DO NOTHING;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE flutter_unity_build TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;