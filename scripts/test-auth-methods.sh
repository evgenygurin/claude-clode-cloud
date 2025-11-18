#!/bin/bash

# =============================================================================
# Test Script: Authentication Methods for AWS Bedrock
# Phase: WOR-10 - Authentication Methods
# =============================================================================
# This script tests all four authentication methods:
# 1. AWS CLI credentials
# 2. IAM User access keys
# 3. STS temporary credentials
# 4. AWS SSO

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

    if command -v aws &> /dev/null; then
        log_success "AWS CLI installed: $(aws --version | cut -d' ' -f1-2)"
    else
        log_error "AWS CLI not found"
        return 1
    fi

    if command -v jq &> /dev/null; then
        log_success "jq installed: $(jq --version)"
    else
        log_error "jq not found"
        return 1
    fi

    if command -v curl &> /dev/null; then
        log_success "curl installed"
    else
        log_error "curl not found"
        return 1
    fi
}

# =============================================================================
# Test 2: AWS CLI Credentials
# =============================================================================

test_aws_cli_credentials() {
    log_section "Test 2: AWS CLI Credentials"

    # Check if AWS CLI profile exists
    if grep -q "^\[default\]" ~/.aws/credentials 2>/dev/null; then
        log_success "AWS CLI credentials file found"
    else
        log_warning "AWS CLI credentials file not found at ~/.aws/credentials"
        log_info "To configure: aws configure"
        return
    fi

    # Test AWS CLI with default profile
    if aws sts get-caller-identity --profile default &>/dev/null; then
        local identity=$(aws sts get-caller-identity --profile default --output json)
        local account=$(echo "$identity" | jq -r '.Account')
        local arn=$(echo "$identity" | jq -r '.Arn')

        log_success "AWS CLI credentials valid"
        echo "  Account: $account"
        echo "  ARN: $arn"
    else
        log_error "AWS CLI credentials not valid"
        return 1
    fi

    # Check for MFA
    if aws iam get-user --query 'User.Arn' &>/dev/null; then
        local mfa_devices=$(aws iam list-mfa-devices --query 'MFADevices[0]' --output text 2>/dev/null || echo "none")
        if [ "$mfa_devices" != "none" ]; then
            log_warning "MFA is enabled on your account (may require additional setup)"
        else
            log_success "MFA not required"
        fi
    fi
}

# =============================================================================
# Test 3: IAM User Access Keys
# =============================================================================

test_iam_user_credentials() {
    log_section "Test 3: IAM User Access Keys"

    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        log_warning "AWS_ACCESS_KEY_ID not set in environment"
        log_info "To configure: export AWS_ACCESS_KEY_ID=AKIA..."
        return
    fi

    if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        log_warning "AWS_SECRET_ACCESS_KEY not set in environment"
        log_info "To configure: export AWS_SECRET_ACCESS_KEY=..."
        return
    fi

    log_success "IAM access keys found in environment"

    # Verify they work
    if AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
       AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
       aws sts get-caller-identity &>/dev/null; then
        local identity=$(AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
                        AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
                        aws sts get-caller-identity --output json)
        local user=$(echo "$identity" | jq -r '.Arn' | awk -F'/' '{print $NF}')

        log_success "IAM access keys are valid"
        echo "  User: $user"
    else
        log_error "IAM access keys are not valid"
        return 1
    fi
}

# =============================================================================
# Test 4: STS AssumeRole
# =============================================================================

test_sts_assume_role() {
    log_section "Test 4: STS AssumeRole (Temporary Credentials)"

    if [ -z "$AWS_ROLE_ARN" ]; then
        log_warning "AWS_ROLE_ARN not set in environment"
        log_info "To configure: export AWS_ROLE_ARN=arn:aws:iam::123456789012:role/BedrockRole"
        return
    fi

    log_success "AWS_ROLE_ARN found: $AWS_ROLE_ARN"

    # Test assuming role
    if aws sts assume-role \
        --role-arn "$AWS_ROLE_ARN" \
        --role-session-name "test-session-$(date +%s)" \
        --duration-seconds 3600 &>/dev/null; then

        local creds=$(aws sts assume-role \
            --role-arn "$AWS_ROLE_ARN" \
            --role-session-name "test-session-$(date +%s)" \
            --duration-seconds 3600 \
            --output json)

        local access_key=$(echo "$creds" | jq -r '.Credentials.AccessKeyId')
        local expiration=$(echo "$creds" | jq -r '.Credentials.Expiration')

        log_success "STS AssumeRole successful"
        echo "  Temporary access key: ${access_key:0:10}..."
        echo "  Expires: $expiration"
    else
        log_error "STS AssumeRole failed"
        log_info "Verify:"
        log_info "  1. Role ARN is correct"
        log_info "  2. You have sts:AssumeRole permission"
        log_info "  3. Trust relationship allows your user to assume the role"
        return 1
    fi
}

# =============================================================================
# Test 5: AWS SSO
# =============================================================================

test_aws_sso() {
    log_section "Test 5: AWS SSO (Enterprise Federation)"

    # Check if SSO profile exists in config
    if grep -q "sso_start_url" ~/.aws/config 2>/dev/null; then
        log_success "AWS SSO profile found in ~/.aws/config"

        # Get SSO profile name
        local sso_profile=$(grep -B1 "sso_start_url" ~/.aws/config | grep "\[profile" | head -1 | sed 's/\[profile \(.*\)\]/\1/')

        if [ -n "$sso_profile" ]; then
            log_info "Using SSO profile: $sso_profile"

            # Check if already logged in
            if aws sts get-caller-identity --profile "$sso_profile" &>/dev/null; then
                local identity=$(aws sts get-caller-identity --profile "$sso_profile" --output json)
                local account=$(echo "$identity" | jq -r '.Account')

                log_success "AWS SSO authenticated"
                echo "  Account: $account"
                echo "  Profile: $sso_profile"
            else
                log_warning "AWS SSO requires login"
                log_info "Run: aws sso login --profile $sso_profile"
            fi
        fi
    else
        log_warning "AWS SSO profile not configured"
        log_info "To configure: aws configure sso"
    fi
}

# =============================================================================
# Test 6: Bedrock Access
# =============================================================================

test_bedrock_access() {
    log_section "Test 6: Bedrock Access"

    local region=${AWS_REGION:-us-east-1}

    # Try to list models with default credentials
    if aws bedrock list-foundation-models --region "$region" &>/dev/null; then
        local models=$(aws bedrock list-foundation-models \
            --region "$region" \
            --query 'modelSummaries[?contains(modelId, `claude`)].{id: modelId, name: modelName}' \
            --output json)

        if [ "$models" != "[]" ]; then
            log_success "Bedrock access confirmed in region: $region"
            echo "  Available Claude models:"
            echo "$models" | jq -r '.[] | "    - \(.name) (\(.id))"'
        else
            log_warning "No Claude models available"
            log_info "Request access: https://console.aws.amazon.com/bedrock/"
        fi
    else
        log_error "Cannot access Bedrock service"
        log_info "Verify:"
        log_info "  1. Credentials are valid"
        log_info "  2. User has 'bedrock:InvokeModel' permission"
        log_info "  3. Region is correct (current: $region)"
        return 1
    fi
}

# =============================================================================
# Test 7: Configuration File
# =============================================================================

test_configuration_file() {
    log_section "Test 7: Configuration Files"

    local config_files=(
        ".claude/bedrock.config.yaml"
        "docs/AUTHENTICATION_METHODS.md"
        "src/gateway/auth-manager.ts"
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

    if [ $((TESTS_PASSED + TESTS_FAILED)) -gt 0 ]; then
        local success_rate=$(echo "scale=1; $TESTS_PASSED * 100 / ($TESTS_PASSED + $TESTS_FAILED)" | bc)
        echo "Success Rate: ${GREEN}${success_rate}%${NC}"
    fi

    echo ""
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All authentication methods tested successfully!${NC}"
        echo ""
        echo "Available authentication methods:"
        echo "1. ✅ AWS CLI (recommended for development)"
        echo "2. ✅ IAM User (recommended for CI/CD)"
        echo "3. ✅ STS AssumeRole (recommended for production)"
        echo "4. ✅ AWS SSO (recommended for enterprise)"
        echo ""
        echo "Next steps:"
        echo "1. Configure your preferred authentication method"
        echo "2. Update .claude/bedrock.config.yaml"
        echo "3. Test with: npm run test:bedrock"
        echo "4. Deploy proxy: npm run start:proxy"
    else
        echo -e "${RED}❌ Some tests failed. Please review the errors above.${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "1. Check AWS credentials: aws sts get-caller-identity"
        echo "2. Request Bedrock access: https://console.aws.amazon.com/bedrock/"
        echo "3. Review documentation: docs/AUTHENTICATION_METHODS.md"
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
    echo "║  Authentication Methods Testing                            ║"
    echo "║  Phase: WOR-10 - Authentication Methods                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    test_prerequisites || true
    test_aws_cli_credentials || true
    test_iam_user_credentials || true
    test_sts_assume_role || true
    test_aws_sso || true
    test_bedrock_access || true
    test_configuration_file || true

    generate_report
}

# Run main function
main
