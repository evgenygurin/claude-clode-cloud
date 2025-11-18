#!/bin/bash
# ============================================================================
# Deployment Script for Claude Code Bedrock Gateway
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Deploying Claude Code Bedrock Gateway${NC}"
echo "======================================"
echo ""

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Docker is required"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required"; exit 1; }

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
cd "$PROJECT_ROOT"
docker build -t claude-code-bedrock:latest .

echo -e "${GREEN}✅ Build complete${NC}"
echo ""
echo "To run locally:"
echo "  docker-compose up -d"
echo ""
echo "To deploy to AWS:"
echo "  1. Push image to ECR"
echo "  2. Deploy to ECS/Fargate"
echo "  3. Configure load balancer"
echo ""
echo "See docs/en/deployment.md for detailed instructions."
