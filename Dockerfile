# Multi-stage Dockerfile for Claude Code + Bedrock Proxy
# Phase: WOR-12 - Docker Containerization
# Purpose: Production-ready containerized deployment with security hardening

# ============================================================================
# STAGE 1: Builder
# ============================================================================
FROM node:22-alpine AS builder

LABEL stage=builder

WORKDIR /app

# Install system dependencies for building
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    cairo-dev \
    jpeg-dev \
    pango-dev \
    giflib-dev \
    ca-certificates

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies with npm ci (production)
RUN npm ci --only=production && \
    npm cache clean --force

# Copy source code
COPY src/ ./src/
COPY scripts/ ./scripts/

# Build TypeScript (if needed)
RUN npm run build 2>/dev/null || true

# ============================================================================
# STAGE 2: Runtime - Slim Image
# ============================================================================
FROM node:22-alpine

LABEL maintainer="Claude Code Team"
LABEL version="1.0.0"
LABEL description="Claude Code + AWS Bedrock Proxy Server"

WORKDIR /app

# Install runtime dependencies only
RUN apk add --no-cache \
    ca-certificates \
    curl \
    bash \
    tini

# Create non-root user for security
RUN addgroup -g 1001 -S claude-code && \
    adduser -S claude-code -u 1001

# Copy built application from builder stage
COPY --from=builder --chown=claude-code:claude-code /app/node_modules ./node_modules
COPY --from=builder --chown=claude-code:claude-code /app/src ./src
COPY --from=builder --chown=claude-code:claude-code /app/scripts ./scripts
COPY --from=builder --chown=claude-code:claude-code /app/package*.json ./

# Copy configuration files (will be mounted or overridden)
COPY --chown=claude-code:claude-code ./.claude/ ./.claude/
COPY --chown=claude-code:claude-code ./docs/ ./docs/

# Switch to non-root user
USER claude-code

# Expose proxy server port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Use tini as PID 1 process for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]

# Default command: Start the Bedrock proxy server
CMD ["npm", "run", "start:proxy"]

# ============================================================================
# Build args and labels
# ============================================================================
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0

LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.revision=$VCS_REF
LABEL org.opencontainers.image.version=$VERSION
LABEL org.opencontainers.image.title="claude-code-bedrock-proxy"
LABEL org.opencontainers.image.description="OpenAI-compatible proxy for AWS Bedrock Claude models"
LABEL org.opencontainers.image.source="https://github.com/anthropics/claude-code-bedrock-proxy"

# ============================================================================
# Security scanning notes
# ============================================================================
# To scan this image:
#   trivy image claude-code:latest
#   snyk container test claude-code:latest
# ============================================================================
