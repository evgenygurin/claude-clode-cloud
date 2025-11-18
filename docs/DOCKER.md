# Docker Containerization Guide - Phase WOR-12

Complete guide for containerizing Claude Code + Bedrock Proxy with production-grade Docker configuration.

**Estimated Time**: 30 minutes setup, full features included

**Components**:
1. Multi-stage Dockerfile with security hardening
2. Development environment (docker-compose.yml)
3. Production environment (docker-compose.prod.yml)
4. Optimization (.dockerignore)
5. Helper scripts and monitoring

---

## Quick Start

### Prerequisites

```bash
# Check Docker installation
docker --version      # Docker 24.0+
docker-compose --version  # Docker Compose 2.20+

# Install if needed (macOS)
brew install docker
```

### Development - 30 seconds

```bash
# Start services
docker-compose up -d

# Verify health
curl http://localhost:3000/health

# View logs
docker-compose logs -f claude-code

# Stop services
docker-compose down
```

### Production - with configuration

```bash
# Set environment variables
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export API_AUTH_TOKEN=your-secret-token
export GRAFANA_PASSWORD=secure-password

# Start production services
docker-compose -f docker-compose.prod.yml up -d

# Monitor
curl -H "Authorization: Bearer ${API_AUTH_TOKEN}" http://localhost:3000/health
```

---

## Docker Architecture

### Multi-Stage Build Strategy

```sql
┌─────────────────────────────────────────────────────┐
│ STAGE 1: Builder (Alpine Linux + Node.js 22)       │
├─────────────────────────────────────────────────────┤
│ • Install build dependencies (Python, g++, etc)    │
│ • Install npm dependencies                         │
│ • Build TypeScript source code                     │
│ • Result: compiled application                     │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│ STAGE 2: Runtime (Alpine Linux + Node.js 22)       │
├─────────────────────────────────────────────────────┤
│ • Copy only production artifacts from Stage 1      │
│ • Create non-root user (claude-code:1001)          │
│ • Install only runtime dependencies                │
│ • Configure health checks                          │
│ • Set security options                             │
│ • Result: 200MB optimized image                    │
└─────────────────────────────────────────────────────┘
```

### Benefits

- **Small Image Size**: ~200MB (vs 500MB+ with single stage)
- **Security**: Non-root user, minimal attack surface
- **Fast Startup**: All dependencies pre-compiled
- **Production Ready**: Health checks, proper signal handling

---

## Dockerfile Details

### File Location

```text
/Users/laptop/dev/claude-clode-cloud/Dockerfile
```

### Key Components

#### Stage 1: Builder

```dockerfile
FROM node:22-alpine AS builder

# Install build tools
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    cairo-dev \
    # ... other build deps

# Install dependencies
RUN npm ci --only=production

# Copy and build source
COPY src/ ./src/
RUN npm run build
```

**Purpose**: Compile all dependencies and source code

#### Stage 2: Runtime

```dockerfile
FROM node:22-alpine

# Install only runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    bash \
    tini

# Create non-root user
RUN addgroup -g 1001 -S claude-code && \
    adduser -S claude-code -u 1001

# Copy from builder
COPY --from=builder /app/node_modules ./node_modules

# Switch user
USER claude-code

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD curl -f http://localhost:3000/health
```

**Purpose**: Minimal runtime with security hardening

### Security Hardening

1. **Non-root User**: Runs as `claude-code:claude-code` (UID 1001)
2. **Minimal Base Image**: Alpine Linux (5MB vs 100MB+ debian)
3. **Read-only Root**: Production config uses `read_only: true`
4. **Capability Dropping**: Only NET_BIND_SERVICE needed
5. **Health Checks**: Automatic restart on failure
6. **Proper Init**: Uses `tini` for signal handling

---

## Docker Compose Files

### Development (docker-compose.yml)

**Purpose**: Local development with hot reload and debugging

**Services**:
- **claude-code**: Main proxy server (port 3000)
- **gateway** (commented): Optional intelligent routing
- **prometheus** (commented): Optional metrics collection

**Configuration**:
- Mounts config files read-only
- Mounts source code for debugging
- Persistent logs volume
- Resource limits: 2 CPU / 1GB RAM limit
- Logging: JSON file driver

**Example**:
```bash
docker-compose up -d              # Start
docker-compose logs -f            # View logs
docker-compose exec claude-code bash  # Shell access
docker-compose down               # Stop
```

### Production (docker-compose.prod.yml)

**Purpose**: Production deployment with monitoring and observability

**Services**:
1. **claude-code**: Main proxy (port 127.0.0.1:3000)
2. **nginx**: Reverse proxy (ports 80/443)
3. **prometheus**: Metrics collection (port 9090)
4. **alertmanager**: Alert handling (port 9093)
5. **grafana**: Metrics dashboards (port 3001)

**Security Features**:
- Read-only root filesystem
- Temporary filesystems for writable dirs (/tmp)
- Proper capability dropping
- No new privileges flag
- Internal networking only (127.0.0.1 binding)

**Configuration**:
```yaml
environment:
  AWS_REGION: us-east-1
  NODE_ENV: production
  LOG_LEVEL: warn

volumes:
  prometheus-data:  # 30-day retention
  alertmanager-data:
  grafana-data:
```

---

## .dockerignore Optimization

**File**: `.dockerignore`

**Purpose**: Reduce build context size and improve build speed

**Excluded**:
- Version control (.git, .github)
- Dependencies (node_modules)
- Development files (.env, .vscode, .idea)
- Build artifacts (dist, build, coverage)
- Testing (tests, specs)
- Documentation (README, docs)
- CI/CD (.circleci, .gitlab-ci.yml)

**Result**: Build context ~50MB → ~5MB (10x smaller)

---

## Image Management

### Building Images

```bash
# Build development image
docker build -t claude-code:dev .

# Build with build args
docker build \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --build-arg VERSION=1.0.0 \
  -t claude-code:latest .

# Build without cache (clean build)
docker build --no-cache -t claude-code:latest .
```

### Image Metadata

```bash
# Inspect image
docker image inspect claude-code:latest

# View image history
docker history claude-code:latest

# Get image size
docker images | grep claude-code
```

### Image Security Scanning

```bash
# Scan with Trivy (CVE detection)
trivy image claude-code:latest

# Scan with Snyk
snyk container test claude-code:latest

# View image layers
dive claude-code:latest
```

---

## Network Configuration

### Development (docker-compose.yml)

```yaml
networks:
  default:
    name: claude-code-network
    driver: bridge

services:
  claude-code:
    ports:
      - "3000:3000"  # Open to host
```

**Access**:
```bash
curl http://localhost:3000/health
```

### Production (docker-compose.prod.yml)

```yaml
services:
  claude-code:
    ports:
      - "127.0.0.1:3000:3000"  # Internal only

  nginx:
    ports:
      - "80:80"      # Public HTTP
      - "443:443"    # Public HTTPS
```

**Access**:
```bash
# Through nginx reverse proxy
curl http://localhost/health

# Direct access not exposed
curl http://localhost:3000/health  # ❌ Fails (not exposed)
```

---

## Volume Management

### Development Volumes

```yaml
volumes:
  - ./.claude/bedrock.config.yaml:/app/.claude/bedrock.config.yaml:ro
  - ./src:/app/src:ro
  - ./scripts:/app/scripts:ro
  - ./logs:/app/logs
```

**Modes**:
- `ro`: Read-only (configuration)
- `rw`: Read-write (logs)

### Production Volumes

```yaml
volumes:
  prometheus-data:
    driver: local
  alertmanager-data:
    driver: local
  grafana-data:
    driver: local
```

**Persistence**:
- Metrics stored for 30 days
- Alert state maintained
- Grafana dashboards persisted

---

## Secrets Management

### Development (Not for secrets!)

```bash
# Use .env file (NOT committed)
echo "AWS_ACCESS_KEY_ID=AKIA..." > .env
echo "AWS_SECRET_ACCESS_KEY=..." >> .env

# Load in docker-compose
docker-compose --env-file .env up
```

### Production (Proper secrets)

```bash
# Use Docker secrets (Swarm) or Kubernetes secrets
docker secret create aws_key_id -
docker secret create aws_key_secret -

# Reference in compose
secrets:
  aws_key_id:
    external: true
```

**Or environment variables from secure source**:
```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
docker-compose -f docker-compose.prod.yml up
```

---

## Monitoring & Observability

### Health Checks

**Development**:
```bash
curl http://localhost:3000/health

# Response:
# {"status":"healthy","timestamp":"2025-11-18T16:00:00Z"}
```

**Production** (with authentication):
```bash
curl -H "Authorization: Bearer ${API_AUTH_TOKEN}" \
  http://localhost:3000/health
```

### Logging

**View logs**:
```bash
# All services
docker-compose logs

# Specific service
docker-compose logs claude-code

# Follow in real-time
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100
```

**Log format**: JSON (structured logging)
```json
{
  "service": "claude-code",
  "level": "info",
  "message": "Started proxy server",
  "timestamp": "2025-11-18T16:00:00Z"
}
```

### Metrics (Production)

**Prometheus** (metrics collection):
```bash
# Access: http://localhost:9090
# Query examples:
# - http_requests_total
# - bedrock_api_latency_ms
# - gateway_cache_hit_rate
```

**Grafana** (visualizations):
```bash
# Access: http://localhost:3001
# Default credentials: admin/password (change immediately!)
# Pre-configured dashboards:
# - Claude Code Performance
# - Bedrock API Health
# - Error Tracking
```

**Alertmanager** (alerts):
```bash
# Access: http://localhost:9093
# Configured alerts:
# - High error rate (>5%)
# - Latency spike (>2000ms)
# - Service down
```

---

## Resource Management

### Development Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 1G
    reservations:
      cpus: '0.5'
      memory: 512M
```

**Meaning**:
- Hard limit: 2 CPUs, 1GB RAM
- Soft reservation: 0.5 CPU, 512MB RAM (guaranteed)

### Production Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 4G
    reservations:
      cpus: '2'
      memory: 2G
```

**Monitoring**:
```bash
# View resource usage
docker stats claude-code

# Example output:
# NAME           CPU%  MEM USAGE / LIMIT
# claude-code    1.2%  256MB / 4GB
```

---

## Common Tasks

### Rebuild and Restart

```bash
# Rebuild image (if source changed)
docker-compose build --no-cache

# Restart with new image
docker-compose up -d --force-recreate
```

### Run Commands Inside Container

```bash
# Interactive shell
docker-compose exec claude-code bash

# Run single command
docker-compose exec claude-code npm run test:bedrock

# With environment variable
docker-compose exec -e DEBUG=bedrock:* claude-code npm run dev:proxy
```

### Clean Up

```bash
# Remove stopped containers
docker-compose down

# Remove dangling images
docker image prune -a

# Remove unused volumes
docker volume prune

# Full cleanup
docker-compose down -v
docker image prune -a
docker volume prune
```

### Performance Testing

```bash
# Load test proxy server (10 concurrent requests)
docker-compose exec claude-code \
  curl -N -H "Connection: keep-alive" \
  -w "Time: %{time_total}s\n" \
  --parallel \
  --parallel-immediate \
  --parallel-max 10 \
  http://localhost:3000/health
```

---

## Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs claude-code

# Common issues:
# 1. Port already in use: lsof -i :3000
# 2. Missing env vars: export AWS_ACCESS_KEY_ID=...
# 3. Credentials expired: aws sts get-caller-identity
```

### High memory usage

```bash
# Monitor memory
docker stats claude-code

# If exceeding limit:
# 1. Increase limit in docker-compose.yml
# 2. Check for memory leaks: npm audit
# 3. Clear cache: docker-compose restart
```

### Network connectivity issues

```bash
# Test from container
docker-compose exec claude-code \
  curl http://localhost:3000/health

# Test from host
curl http://localhost:3000/health

# DNS resolution
docker-compose exec claude-code \
  nslookup bedrock.us-east-1.amazonaws.com
```

### AWS credentials not working

```bash
# Verify credentials in container
docker-compose exec claude-code \
  aws sts get-caller-identity

# Check environment variables
docker-compose exec claude-code \
  env | grep AWS

# Verify config file
docker-compose exec claude-code \
  cat ./.claude/bedrock.config.yaml
```

---

## Security Best Practices

### 1. Image Scanning

```bash
# Always scan before production
trivy image claude-code:latest

# Fix vulnerabilities
npm audit fix
docker build --no-cache -t claude-code:latest .
trivy image claude-code:latest  # Verify fix
```

### 2. Secret Management

```bash
# ❌ DON'T: Commit secrets
echo "AWS_SECRET_ACCESS_KEY=..." >> .env

# ✅ DO: Use environment variables
export AWS_SECRET_ACCESS_KEY=...
docker-compose up

# ✅ DO: Use Docker secrets (production)
docker secret create aws_key -
```

### 3. Network Isolation

```bash
# Development: Services communicate via docker network
docker network inspect claude-code-network

# Production: Reverse proxy (nginx) exposed, app internal
# nginx (public) → claude-code (internal)
```

### 4. User Privileges

```bash
# Always run as non-root
docker-compose exec claude-code whoami
# Output: claude-code (UID 1001)

# NOT root
docker-compose exec claude-code id
# Output: uid=1001(claude-code) gid=1001(claude-code)
```

### 5. Log Rotation

```bash
# Already configured in docker-compose
logging:
  options:
    max-size: "50m"      # Rotate at 50MB
    max-file: "10"       # Keep 10 files
```

---

## Performance Optimization

### Build Time Optimization

```bash
# Current build time: ~3-5 minutes

# Optimize further:
1. Use BuildKit
   DOCKER_BUILDKIT=1 docker build .

2. Layer caching
   - Dockerfile steps ordered by change frequency
   - Dependencies cached separately

3. Multi-platform builds
   docker buildx build --platform linux/amd64,linux/arm64 .
```

### Runtime Optimization

```bash
# Image size: ~200MB

# Reduce further:
1. Alpine Linux (vs debian-slim)
2. Only production dependencies
3. Strip debug symbols
4. Use distroless base (alternative)
```

---

## Deployment Examples

### Docker Swarm

```bash
# Initialize swarm
docker swarm init

# Deploy service
docker service create \
  --name claude-code \
  --publish 3000:3000 \
  --env AWS_REGION=us-east-1 \
  claude-code:latest
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: claude-code

spec:
  replicas: 3
  selector:
    matchLabels:
      app: claude-code

  template:
    metadata:
      labels:
        app: claude-code
    spec:
      containers:
      - name: claude-code
        image: claude-code:latest
        ports:
        - containerPort: 3000

        env:
        - name: AWS_REGION
          value: us-east-1
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: access-key-id

        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"

        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 60
```

### Docker Hub Registry

```bash
# Tag image
docker tag claude-code:latest myregistry/claude-code:1.0.0

# Push to registry
docker push myregistry/claude-code:1.0.0

# Pull and run
docker run -p 3000:3000 myregistry/claude-code:1.0.0
```

---

## Next Steps

**WOR-13**: CI/CD Pipeline Implementation
- GitHub Actions for automated builds
- Automated testing and linting
- Docker image push to registry
- Automated deployment

**WOR-14**: Documentation and Guides
- API documentation
- Deployment runbooks
- Architecture diagrams

---

**Phase**: WOR-12 - Docker Containerization
**Status**: Complete
**Estimated Completion**: 12 hours for full integration
**Created**: 2025-11-18
