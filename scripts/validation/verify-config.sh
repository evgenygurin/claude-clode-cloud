#!/bin/bash
# ============================================================================
# Configuration Verification Script
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

echo -e "${GREEN}🔍 Verifying Claude Code Bedrock Configuration${NC}"
echo "=============================================="
echo ""

# Check required environment variables
check_var() {
    local var_name=$1
    local var_value="${!var_name:-}"
    
    if [ -z "$var_value" ]; then
        echo -e "${RED}❌ ${var_name} is not set${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    else
        echo -e "${GREEN}✅ ${var_name}=${var_value}${NC}"
        return 0
    fi
}

# Check CLAUDE_CODE_USE_BEDROCK
if [ "${CLAUDE_CODE_USE_BEDROCK:-}" != "1" ]; then
    echo -e "${RED}❌ CLAUDE_CODE_USE_BEDROCK is not set to 1${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ CLAUDE_CODE_USE_BEDROCK=1${NC}"
fi

# Check AWS_REGION
check_var "AWS_REGION"

# Validate region
if [[ ! "$AWS_REGION" =~ ^(us-east-1|us-west-2)$ ]]; then
    echo -e "${RED}❌ AWS_REGION must be us-east-1 or us-west-2${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check model IDs
check_var "ANTHROPIC_MODEL"
check_var "ANTHROPIC_SMALL_FAST_MODEL"

# Check AWS credentials
echo ""
echo -e "${YELLOW}Checking AWS credentials...${NC}"

if command -v aws >/dev/null 2>&1; then
    if aws sts get-caller-identity >/dev/null 2>&1; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        echo -e "${GREEN}✅ AWS credentials valid (Account: ${ACCOUNT_ID})${NC}"
    else
        echo -e "${RED}❌ AWS credentials not configured or invalid${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠️  AWS CLI not found, skipping credential check${NC}"
fi

# Check optional variables
echo ""
echo -e "${YELLOW}Checking optional configuration...${NC}"

if [ -n "${CLAUDE_CODE_MAX_OUTPUT_TOKENS:-}" ]; then
    echo -e "${GREEN}✅ CLAUDE_CODE_MAX_OUTPUT_TOKENS=${CLAUDE_CODE_MAX_OUTPUT_TOKENS}${NC}"
else
    echo -e "${YELLOW}⚠️  CLAUDE_CODE_MAX_OUTPUT_TOKENS not set (using default)${NC}"
fi

if [ -n "${MAX_THINKING_TOKENS:-}" ]; then
    echo -e "${GREEN}✅ MAX_THINKING_TOKENS=${MAX_THINKING_TOKENS}${NC}"
else
    echo -e "${YELLOW}⚠️  MAX_THINKING_TOKENS not set (using default)${NC}"
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Found ${ERRORS} error(s)${NC}"
    exit 1
fi
