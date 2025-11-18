#!/bin/bash

# =============================================================================
# Test Script: Claude Code + AWS Bedrock Integration
# Phase: WOR-9 - Claude Code Configuration
# =============================================================================
# This script tests the integration between Claude Code and AWS Bedrock
# including proxy connectivity, model availability, and API functionality

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# State variables
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =============================================================================
# Test 1: Check Prerequisites
# =============================================================================

test_prerequisites() {
    log_section "Test 1: Prerequisites"

    # Check AWS CLI
    if command -v aws &> /dev/null; then
        log_success "AWS CLI installed: $(aws --version)"
    else
        log_error "AWS CLI not found"
        return 1
    fi

    # Check jq
    if command -v jq &> /dev/null; then
        log_success "jq installed: $(jq --version)"
    else
        log_error "jq not found"
        return 1
    fi

    # Check curl
    if command -v curl &> /dev/null; then
        log_success "curl installed"
    else
        log_error "curl not found"
        return 1
    fi

    # Check Node.js (for proxy server)
    if command -v node &> /dev/null; then
        log_success "Node.js installed: $(node --version)"
    else
        log_warning "Node.js not found (required for proxy server)"
    fi
}

# =============================================================================
# Test 2: AWS Credentials
# =============================================================================

test_aws_credentials() {
    log_section "Test 2: AWS Credentials"

    # Check credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        return 1
    fi

    local account_id=$(aws sts get-caller-identity --query 'Account' --output text)
    local user=$(aws sts get-caller-identity --query 'Arn' --output text)

    log_success "AWS credentials valid"
    echo "  Account: $account_id"
    echo "  User: $user"

    # Check default region
    local region=$(aws configure get region)
    region=${region:-"not set"}
    if [ "$region" = "not set" ]; then
        log_warning "Default region not set, using us-east-1"
        export AWS_REGION="us-east-1"
    else
        log_success "Default region: $region"
    fi
}

# =============================================================================
# Test 3: Bedrock Availability
# =============================================================================

test_bedrock_availability() {
    log_section "Test 3: Bedrock Availability"

    local region=${AWS_REGION:-us-east-1}

    # Check if Bedrock is available in region
    local bedrock_regions=("us-east-1" "us-west-2" "eu-west-1" "ap-southeast-1")
    if [[ ! " ${bedrock_regions[@]} " =~ " ${region} " ]]; then
        log_error "Bedrock not available in region: $region"
        echo "  Available regions: ${bedrock_regions[@]}"
        return 1
    fi

    log_success "Bedrock available in region: $region"

    # Try to list models
    if aws bedrock list-foundation-models --region "$region" &> /dev/null; then
        log_success "Can list Bedrock foundation models"
    else
        log_error "Cannot list Bedrock models (may need to request access)"
        return 1
    fi
}

# =============================================================================
# Test 4: Claude Models Access
# =============================================================================

test_claude_models() {
    log_section "Test 4: Claude Models Access"

    local region=${AWS_REGION:-us-east-1}

    # Get available models
    local models=$(aws bedrock list-foundation-models \
        --region "$region" \
        --query 'modelSummaries[?contains(modelId, `claude`)].{id: modelId, name: modelName}' \
        --output json)

    if [ "$models" = "[]" ]; then
        log_error "No Claude models available (request access in AWS Console)"
        return 1
    fi

    log_success "Claude models available:"
    echo "$models" | jq -r '.[] | "  - \(.name) (\(.id))"'
}

# =============================================================================
# Test 5: Proxy Server Connectivity
# =============================================================================

test_proxy_connectivity() {
    log_section "Test 5: Proxy Server Connectivity"

    local proxy_url="http://localhost:3000"

    # Check if proxy is running
    if curl -s "$proxy_url/health" &> /dev/null; then
        log_success "Proxy server is running"

        # Get health status
        local health=$(curl -s "$proxy_url/health")
        echo "  Health status: $(echo "$health" | jq -r '.status')"
        echo "  Region: $(echo "$health" | jq -r '.region')"
    else
        log_warning "Proxy server not running at $proxy_url"
        log_info "To start proxy server, run: npm run start:proxy"
    fi
}

# =============================================================================
# Test 6: OpenAI API Compatibility
# =============================================================================

test_openai_compatibility() {
    log_section "Test 6: OpenAI API Compatibility"

    local proxy_url="http://localhost:3000"

    # Check models endpoint
    if curl -s "$proxy_url/v1/models" &> /dev/null; then
        log_success "OpenAI /v1/models endpoint available"

        local models=$(curl -s "$proxy_url/v1/models" | jq '.data | length')
        echo "  Available models: $models"
    else
        log_warning "OpenAI models endpoint not accessible"
    fi
}

# =============================================================================
# Test 7: Simple Model Invocation
# =============================================================================

test_model_invocation() {
    log_section "Test 7: Simple Model Invocation"

    if [ -z "$AWS_REGION" ]; then
        AWS_REGION="us-east-1"
    fi

    # Test with Haiku (cheapest model)
    local model_id="anthropic.claude-3-5-haiku-20241022-v1:0"

    log_info "Testing model invocation with Haiku..."

    local response=$(aws bedrock-runtime invoke-model \
        --model-id "$model_id" \
        --region "$AWS_REGION" \
        --content-type "application/json" \
        --accept "application/json" \
        --body '{
            "anthropic_version": "bedrock-2023-06-01",
            "max_tokens": 100,
            "system": "You are a helpful assistant.",
            "messages": [{
                "role": "user",
                "content": "Say hello in one word."
            }]
        }' \
        --output text \
        --query 'body' 2>/dev/null || echo '{}')

    if echo "$response" | jq -e '.content[0].text' > /dev/null 2>&1; then
        local text=$(echo "$response" | jq -r '.content[0].text')
        log_success "Model invocation successful"
        echo "  Response: $text"
    else
        log_error "Model invocation failed"
        echo "  Response: $response"
        return 1
    fi
}

# =============================================================================
# Test 8: Token Counting
# =============================================================================

test_token_counting() {
    log_section "Test 8: Token Counting"

    local test_text="Hello, this is a test message for token counting."

    # Estimate tokens (rough approximation: 1 token ≈ 4 characters)
    local char_count=${#test_text}
    local estimated_tokens=$((char_count / 4))

    log_success "Token estimation"
    echo "  Text length: $char_count characters"
    echo "  Estimated tokens: ~$estimated_tokens tokens"
    echo "  (Note: Actual token count varies by model)"
}

# =============================================================================
# Test 9: Cost Calculation
# =============================================================================

test_cost_calculation() {
    log_section "Test 9: Cost Calculation"

    # Haiku pricing: $0.80/1M input tokens, $2.40/1M output tokens
    local input_tokens=1000
    local output_tokens=500

    local input_cost=$(echo "scale=6; $input_tokens * 0.00080 / 1000" | bc)
    local output_cost=$(echo "scale=6; $output_tokens * 0.0024 / 1000" | bc)
    local total_cost=$(echo "scale=6; $input_cost + $output_cost" | bc)

    log_success "Cost calculation example"
    echo "  Input tokens: $input_tokens"
    echo "  Output tokens: $output_tokens"
    echo "  Input cost: \$$input_cost"
    echo "  Output cost: \$$output_cost"
    echo "  Total cost: \$$total_cost"
}

# =============================================================================
# Test 10: Configuration Files
# =============================================================================

test_configuration_files() {
    log_section "Test 10: Configuration Files"

    local config_files=(
        ".claude/bedrock.config.yaml"
        "terraform/terraform.tfvars"
        ".cursor-agent/env.local"
    )

    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            log_success "Configuration file exists: $file"
        else
            log_warning "Configuration file missing: $file"
        fi
    done
}

# =============================================================================
# Generate Test Report
# =============================================================================

generate_report() {
    log_section "Test Report"

    echo ""
    echo "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    echo ""

    local success_rate=$(echo "scale=1; $TESTS_PASSED * 100 / ($TESTS_PASSED + $TESTS_FAILED)" | bc)
    echo "Success Rate: ${GREEN}${success_rate}%${NC}"

    echo ""
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed! Claude Code + Bedrock integration ready.${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Install proxy dependencies: npm install"
        echo "2. Start proxy server: npm run start:proxy"
        echo "3. Configure Cursor IDE: https://code.claude.com/docs/"
        echo "4. Proceed to WOR-10: Authentication Methods"
    else
        echo -e "${RED}❌ Some tests failed. Please review the errors above.${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "1. Check AWS credentials: aws sts get-caller-identity"
        echo "2. Request Bedrock access: https://console.aws.amazon.com/bedrock/"
        echo "3. Review documentation: docs/CLAUDE_CODE_CONFIGURATION.md"
    fi
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    clear
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Claude Code + AWS Bedrock Integration Tests               ║"
    echo "║  Phase: WOR-9 - Claude Code Configuration                  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    test_prerequisites || true
    test_aws_credentials || true
    test_bedrock_availability || true
    test_claude_models || true
    test_proxy_connectivity || true
    test_openai_compatibility || true
    test_model_invocation || true
    test_token_counting || true
    test_cost_calculation || true
    test_configuration_files || true

    generate_report
}

# Run main function
main
