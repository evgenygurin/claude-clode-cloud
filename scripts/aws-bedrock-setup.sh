#!/bin/bash

# =============================================================================
# AWS Bedrock Setup Script
# Configures AWS credentials and enables Bedrock models
# Phase: WOR-8 - AWS Infrastructure Setup
# =============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Step 1: Verify Prerequisites
# =============================================================================

verify_prerequisites() {
    log_info "Verifying prerequisites..."

    # Check for required tools
    local required_tools=("aws" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "Required tool not found: $tool"
            echo "Install with: brew install $tool"
            exit 1
        fi
    done

    log_success "All prerequisites verified"
}

# =============================================================================
# Step 2: Check AWS Credentials
# =============================================================================

check_aws_credentials() {
    log_info "Checking AWS credentials..."

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        echo "Configure with: aws configure"
        exit 1
    fi

    local account_id=$(aws sts get-caller-identity --query 'Account' --output text)
    local user_arn=$(aws sts get-caller-identity --query 'Arn' --output text)

    log_success "AWS credentials verified"
    echo "  Account ID: $account_id"
    echo "  User: $user_arn"
}

# =============================================================================
# Step 3: Verify AWS Region and Bedrock Availability
# =============================================================================

verify_bedrock_region() {
    log_info "Verifying Bedrock availability in region..."

    local current_region=$(aws configure get region)
    if [ -z "$current_region" ]; then
        current_region="us-east-1"
        log_warning "No default region set, using us-east-1"
    fi

    # Check if Bedrock is available in the region
    local bedrock_regions=("us-east-1" "us-west-2" "eu-west-1" "ap-southeast-1")
    if [[ ! " ${bedrock_regions[@]} " =~ " ${current_region} " ]]; then
        log_error "Bedrock is not available in region: $current_region"
        echo "Available regions: ${bedrock_regions[@]}"
        exit 1
    fi

    log_success "Bedrock is available in region: $current_region"
}

# =============================================================================
# Step 4: Enable Bedrock Model Access
# =============================================================================

enable_model_access() {
    log_info "Configuring Bedrock model access..."

    local region=$(aws configure get region)
    region=${region:-us-east-1}

    # Get available foundation models
    log_info "Fetching available models..."
    local models=$(aws bedrock list-foundation-models \
        --region "$region" \
        --query 'modelSummaries[*].[modelId, modelName]' \
        --output text)

    if [ -z "$models" ]; then
        log_warning "No models found. You may need to request access in the AWS Console."
        echo "Visit: https://console.aws.amazon.com/bedrock/home?region=$region#/foundation-models"
    else
        log_success "Available models in $region:"
        echo "$models" | while read -r model_id model_name; do
            echo "  ✓ $model_name ($model_id)"
        done
    fi
}

# =============================================================================
# Step 5: Create IAM User for Bedrock Access (Optional)
# =============================================================================

create_bedrock_iam_user() {
    local username="cursor-bedrock-agent"

    log_info "Setting up IAM user for Bedrock access..."

    # Check if user already exists
    if aws iam get-user --user-name "$username" &> /dev/null; then
        log_warning "IAM user '$username' already exists"
        return
    fi

    # Create user
    log_info "Creating IAM user: $username"
    aws iam create-user --user-name "$username" --tags Key=Project,Value=claude-code-bedrock

    # Create access key
    log_info "Creating access key..."
    local access_key_output=$(aws iam create-access-key --user-name "$username")
    local access_key=$(echo "$access_key_output" | jq -r '.AccessKey.AccessKeyId')
    local secret_key=$(echo "$access_key_output" | jq -r '.AccessKey.SecretAccessKey')

    # Attach inline policy for Bedrock
    log_info "Attaching Bedrock policy..."
    aws iam put-user-policy --user-name "$username" \
        --policy-name BedrockAccess \
        --policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "bedrock:InvokeModel",
                        "bedrock:InvokeModelWithResponseStream",
                        "bedrock:GetFoundationModel",
                        "bedrock:ListFoundationModels"
                    ],
                    "Resource": "*"
                }
            ]
        }'

    log_success "IAM user created successfully!"
    echo ""
    echo "Access Key ID: $access_key"
    echo "Secret Access Key: $secret_key"
    echo ""
    log_warning "Save these credentials securely! You won't be able to view the secret key again."
}

# =============================================================================
# Step 6: Validate Bedrock Access
# =============================================================================

validate_bedrock_access() {
    log_info "Validating Bedrock access..."

    local region=$(aws configure get region)
    region=${region:-us-east-1}

    # Try to invoke a simple model call
    if aws bedrock list-foundation-models --region "$region" &> /dev/null; then
        log_success "Bedrock access validated successfully"
    else
        log_error "Cannot access Bedrock. Check IAM permissions."
        exit 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   AWS Bedrock Setup for Claude Code Integration            ║"
    echo "║   Phase: WOR-8 - AWS Infrastructure Setup                  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    verify_prerequisites
    check_aws_credentials
    verify_bedrock_region
    enable_model_access
    validate_bedrock_access

    echo ""
    log_success "AWS Bedrock setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. Review Bedrock model access in AWS Console"
    echo "2. Deploy Terraform configuration: terraform apply"
    echo "3. Configure LLM Gateway proxy (WOR-11)"
    echo ""
}

# Run main function
main
