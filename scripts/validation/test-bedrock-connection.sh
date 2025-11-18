#!/bin/bash
# ============================================================================
# Test Bedrock Connection Script
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

AWS_REGION="${AWS_REGION:-us-east-1}"
MODEL_ID="${ANTHROPIC_MODEL:-anthropic.claude-sonnet-4-5-20250929-v1:0}"

echo -e "${GREEN}🧪 Testing AWS Bedrock Connection${NC}"
echo "===================================="
echo ""
echo "Region: ${AWS_REGION}"
echo "Model: ${MODEL_ID}"
echo ""

# Check AWS CLI
if ! command -v aws >/dev/null 2>&1; then
    echo -e "${RED}❌ AWS CLI not found${NC}"
    exit 1
fi

# Check credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ AWS Account: ${ACCOUNT_ID}${NC}"
echo ""

# Test 1: List foundation models
echo -e "${YELLOW}Test 1: Listing foundation models...${NC}"
if aws bedrock list-foundation-models \
    --region "$AWS_REGION" \
    --query 'modelSummaries[?providerName==`Anthropic`]' \
    --output json >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Can list Anthropic models${NC}"
else
    echo -e "${RED}❌ Cannot list models - check Bedrock access${NC}"
    exit 1
fi

# Test 2: Get specific model
echo -e "${YELLOW}Test 2: Getting model information...${NC}"
if aws bedrock get-foundation-model \
    --region "$AWS_REGION" \
    --model-identifier "$MODEL_ID" \
    --output json >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Model ${MODEL_ID} is accessible${NC}"
else
    echo -e "${RED}❌ Cannot access model ${MODEL_ID}${NC}"
    exit 1
fi

# Test 3: Invoke model (simple test)
echo -e "${YELLOW}Test 3: Testing model invocation...${NC}"

TEST_BODY=$(cat <<EOF
{
  "anthropic_version": "bedrock-2023-05-31",
  "max_tokens": 10,
  "messages": [
    {
      "role": "user",
      "content": "Hello"
    }
  ]
}
EOF
)

if aws bedrock invoke-model \
    --region "$AWS_REGION" \
    --model-id "$MODEL_ID" \
    --body "$TEST_BODY" \
    --cli-binary-format raw-in-base64-out \
    --output json >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Model invocation successful${NC}"
else
    echo -e "${RED}❌ Model invocation failed - check IAM permissions${NC}"
    echo "Required permissions: bedrock:InvokeModel"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 All tests passed!${NC}"
echo ""
echo "Your Bedrock configuration is working correctly."
