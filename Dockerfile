# Multi-stage Dockerfile for Node.js Backend & React Frontend

# Stage 1: Build React Frontend
FROM node:18-alpine AS react-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY frontend/ ./
RUN npm run build

# Stage 2: Build Node.js Backend
FROM node:18-alpine AS node-build
WORKDIR /app/backend
COPY backend/package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY backend/ ./

# Stage 3: Final lightweight image
FROM node:18-alpine AS production
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy built backend
COPY --from=node-build --chown=nodejs:nodejs /app/backend ./backend
# Copy built React app
COPY --from=react-build --chown=nodejs:nodejs /app/frontend/build ./backend/public

# Install only production dependencies
WORKDIR /app/backend
RUN npm ci --only=production && npm cache clean --force

# Security: Remove unnecessary packages
RUN apk del --purge wget curl && \
    rm -rf /var/cache/apk/*

USER nodejs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

CMD ["node", "server.js"]
