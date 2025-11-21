# Backend Dockerfile
FROM node:18-alpine

# Install system dependencies
RUN apk add --no-cache \
    git \
    bash \
    python3 \
    make \
    g++ \
    cairo-dev \
    jpeg-dev \
    pango-dev \
    giflib-dev

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci

# Copy Prisma schema
COPY prisma ./prisma

# Generate Prisma client
RUN npx prisma generate

# Copy source code
COPY src ./src

# Copy scripts
COPY scripts ./scripts
RUN chmod +x scripts/*.sh 2>/dev/null || true

# Build TypeScript
RUN npm run build

# Create necessary directories
RUN mkdir -p /app/logs /app/artifacts /app/temp

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start command
CMD ["npm", "start"]