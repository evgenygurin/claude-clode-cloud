# Authentication Methods - Phase WOR-10

Complete guide for configuring the four authentication methods for AWS Bedrock access.

## Overview

Claude Code supports four authentication methods for accessing AWS Bedrock:

1. **AWS CLI** - Default method, uses ~/.aws/credentials
2. **IAM User** - Direct access keys, good for CI/CD
3. **STS AssumeRole** - Temporary credentials, cross-account access
4. **AWS SSO** - Enterprise federated access

**Estimated Setup Time**: 5 hours total (WOR-10)

## Quick Start

### Method 1: AWS CLI (Recommended for Development)

**Setup Time**: 10 minutes

```bash
# 1. Install AWS CLI
brew install awscli

# 2. Configure credentials
aws configure

# You'll be prompted for:
# AWS Access Key ID: [your access key]
# AWS Secret Access Key: [your secret key]
# Default region: us-east-1
# Default output format: json

# 3. Verify configuration
aws sts get-caller-identity

# 4. Update .claude/bedrock.config.yaml
authentication:
  method: aws_cli
  config:
    profile: default
    region: us-east-1
```

**When to use**:
- Local development
- Single user setup
- Most user-friendly
- Works with MFA

---

## Authentication Methods - Detailed Guide

### Method 1: AWS CLI Credentials

**File locations**:
- Credentials: `~/.aws/credentials`
- Config: `~/.aws/config`

**Credentials file format**:
```ini
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[production]
aws_access_key_id = AKIA2IOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY2
```

**Config file format**:
```ini
[default]
region = us-east-1
output = json

[profile production]
region = us-east-1
output = json
```

#### Setup Instructions

```bash
# Step 1: Get access keys from AWS Console
# 1. Go to: https://console.aws.amazon.com/iam/
# 2. Click "Users" → your username
# 3. Click "Security credentials" tab
# 4. Click "Create access key"
# 5. Copy both keys

# Step 2: Configure using CLI
aws configure --profile default
# Follow prompts to enter Access Key ID and Secret Access Key

# Step 3: Verify
aws sts get-caller-identity --profile default

# Example output:
# {
#   "UserId": "AIDAI...",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/claudecode"
# }
```

#### Configuration in bedrock.config.yaml

```yaml
authentication:
  method: aws_cli
  config:
    credentials_file: ~/.aws/credentials
    config_file: ~/.aws/config
    profile: default
    region: us-east-1
```

#### Advantages

- ✅ No secrets in code
- ✅ Works with existing AWS CLI setup
- ✅ Supports multiple profiles
- ✅ Can use MFA if configured
- ✅ Most common method

#### Disadvantages

- ❌ Requires AWS CLI installation
- ❌ MFA may require manual intervention
- ❌ Not suitable for unattended CI/CD without extra setup

#### Common Issues

**Error**: "Unable to locate credentials"
```bash
# Solution: Verify credentials file exists
cat ~/.aws/credentials

# If missing, run:
aws configure
```

**Error**: "The security token included in the request is invalid"
```bash
# Solution: MFA might be required
# If your IAM user has MFA enabled:
# 1. Use STS method instead, OR
# 2. Use IAM User method with temporary credentials
```

---

### Method 2: IAM User Access Keys

**Setup Time**: 15 minutes

Direct access key credentials, ideal for CI/CD pipelines and automation.

#### Setup Instructions

```bash
# Step 1: Create IAM User (if not using existing)
# Via AWS Console:
# 1. Go to: https://console.aws.amazon.com/iam/
# 2. Click "Users" → "Create user"
# 3. Enter username: cursor-agent-bedrock
# 4. Check "Provide user access to the AWS Management Console" (optional)

# Step 2: Attach Policy (Bedrock Access)
# In AWS Console:
# 1. Select user → "Permissions" tab
# 2. Click "Add permissions" → "Attach policies directly"
# 3. Search for "AmazonBedrockFullAccess" (or create custom policy)
# 4. Click "Attach policies"

# Step 3: Create Access Keys
# In AWS Console:
# 1. Select user → "Security credentials" tab
# 2. Scroll to "Access keys"
# 3. Click "Create access key"
# 4. Select "Command Line Interface (CLI)"
# 5. Copy both keys immediately

# Step 4: Configure environment variables
# Option A: In .env file
cat > .env << 'EOF'
AWS_ACCESS_KEY_ID=AKIA2IOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY2
AWS_REGION=us-east-1
EOF

# Option B: In shell profile (~/.bashrc or ~/.zshrc)
export AWS_ACCESS_KEY_ID=AKIA2IOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY2
export AWS_REGION=us-east-1

# Step 5: Verify credentials
aws sts get-caller-identity

# Expected output:
# {
#   "UserId": "AIDAI...",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/cursor-agent-bedrock"
# }
```

#### Configuration in bedrock.config.yaml

```yaml
authentication:
  method: iam_user
  config:
    access_key_id: ${AWS_ACCESS_KEY_ID}
    secret_access_key: ${AWS_SECRET_ACCESS_KEY}
    region: us-east-1
```

#### Advantages

- ✅ Simple and direct
- ✅ No AWS CLI required
- ✅ Good for CI/CD pipelines
- ✅ Works with Docker containers
- ✅ Can be used in Lambda functions

#### Disadvantages

- ❌ Long-lived credentials (security risk)
- ❌ Must be rotated regularly
- ❌ Should never be committed to git
- ❌ Less secure than STS or SSO

#### Security Best Practices

```bash
# 1. Use least privilege policy
# Attach only "AmazonBedrockFullAccess" or custom policy with:
# - bedrock:InvokeModel
# - bedrock:ListFoundationModels

# 2. Rotate keys every 90 days
# In AWS Console:
# 1. Select user → "Security credentials"
# 2. Create new access key
# 3. Update application with new key
# 4. Deactivate old key after verification
# 5. Delete old key after 7 days

# 3. Monitor key usage
# Via AWS CloudTrail:
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=AKIA... \
  --max-results 10

# 4. Set up AWS Budgets alert for unusual activity
# 1. Go to: https://console.aws.amazon.com/cost-management/home
# 2. Create budget alert for unauthorized access patterns
```

#### Common Issues

**Error**: "User: arn:aws:iam::123456789012:user/cursor-agent-bedrock is not authorized"
```bash
# Solution: Attach Bedrock policy to user
# In AWS Console:
# 1. Go to IAM → Users → user → Permissions
# 2. Add policy "AmazonBedrockFullAccess"
```

**Error**: "The Access Key ID: AKIA... does not exist"
```bash
# Solution: Access key might be deleted or wrong
# Verify in AWS Console:
# 1. Go to IAM → Users → Security credentials
# 2. Check if key exists and is "Active"
# 3. If missing, create new key
```

---

### Method 3: STS AssumeRole (Temporary Credentials)

**Setup Time**: 30 minutes

Temporary credentials (1-12 hours) by assuming an IAM role. Best for cross-account access and time-limited permissions.

#### Architecture

```bash
Base Credentials → Assume Role → Temporary Credentials (1-12 hrs)
    (AWS CLI)        (STS)         (for Bedrock)
```

#### Setup Instructions

```bash
# Step 1: Create IAM Role (in AWS Console)
# 1. Go to: https://console.aws.amazon.com/iam/
# 2. Click "Roles" → "Create role"
# 3. Select "AWS account" as trusted entity
# 4. Enter your account ID: 123456789012
# 5. Click "Next"

# Step 2: Attach Bedrock policy to role
# 1. Search for "AmazonBedrockFullAccess"
# 2. Check the box
# 3. Click "Next"
# 4. Enter role name: BedrockAccessRole
# 5. Click "Create role"

# Step 3: Copy Role ARN
# 1. Click role name "BedrockAccessRole"
# 2. Copy ARN from top of page
# Example: arn:aws:iam::123456789012:role/BedrockAccessRole

# Step 4: Trust yourself (allow your user to assume role)
# 1. Click "Trust relationships" tab
# 2. Click "Edit trust policy"
# 3. Update to:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:user/your-username"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
# 4. Click "Update policy"

# Step 5: Test assuming role
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/BedrockAccessRole \
  --role-session-name test-session \
  --duration-seconds 3600

# Expected output:
# {
#   "Credentials": {
#     "AccessKeyId": "ASIA...",
#     "SecretAccessKey": "...",
#     "SessionToken": "...",
#     "Expiration": "2025-11-18T13:00:00Z"
#   }
# }
```

#### Configuration in bedrock.config.yaml

```yaml
authentication:
  method: sts
  config:
    role_arn: arn:aws:iam::123456789012:role/BedrockAccessRole
    session_name: cursor-agent-session
    duration_seconds: 3600
    region: us-east-1
    # Optional for cross-account:
    # external_id: unique-external-id
```

#### Advantages

- ✅ Temporary credentials (1-12 hours)
- ✅ No long-lived secrets
- ✅ Good for cross-account access
- ✅ Audit trail in CloudTrail
- ✅ Fine-grained access control

#### Disadvantages

- ❌ Slightly more complex setup
- ❌ Requires base credentials (AWS CLI or IAM user)
- ❌ Additional STS call overhead

#### Use Cases

**Lambda Function Execution**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Cross-Account Access**:
```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::OTHER-ACCOUNT:root"
  },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": {
      "sts:ExternalId": "unique-external-id-12345"
    }
  }
}
```

#### Credential Rotation Script

```bash
#!/bin/bash
# Automatically rotate STS credentials hourly

ROLE_ARN="arn:aws:iam::123456789012:role/BedrockAccessRole"
SESSION_NAME="cursor-agent-$(date +%s)"
DURATION=3600

# Assume role and export credentials
CREDENTIALS=$(aws sts assume-role \
  --role-arn $ROLE_ARN \
  --role-session-name $SESSION_NAME \
  --duration-seconds $DURATION \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text)

IFS=' ' read -r ACCESS_KEY SECRET_KEY SESSION_TOKEN <<< "$CREDENTIALS"

export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
export AWS_SESSION_TOKEN=$SESSION_TOKEN

echo "✅ STS credentials rotated (expires in $DURATION seconds)"
```

---

### Method 4: AWS SSO (Enterprise Federation)

**Setup Time**: 1-2 hours (depending on SSO setup)

Enterprise-grade authentication using AWS IAM Identity Center (formerly AWS SSO).

#### Prerequisites

- AWS SSO enabled in your AWS account
- SSO provider configured (Okta, Azure AD, Google Workspace, etc.)
- User assigned to account with permission set

#### Setup Instructions

```bash
# Step 1: Enable AWS IAM Identity Center (if not already done)
# 1. Go to: https://console.aws.amazon.com/singlesignon/
# 2. Click "Enable" (may take 5-10 minutes)
# 3. Note the Access Portal URL (e.g., https://d-xxxxx.awsapps.com/)

# Step 2: Configure identity source
# 1. In IAM Identity Center console
# 2. Click "Settings" (left sidebar)
# 3. Choose identity source: "External identity provider" or "Identity Center directory"

# Step 3: Create or use existing permission set
# 1. Click "Permission sets" (left sidebar)
# 2. Create new or use existing "BedrockAccess" set
# 3. Attach policy: AmazonBedrockFullAccess

# Step 4: Assign user to account
# 1. Click "AWS accounts" (left sidebar)
# 2. Select your account
# 3. Click "Assign users or groups"
# 4. Select user → BedrockAccess permission set
# 5. Click "Submit"

# Step 5: Configure AWS CLI for SSO
aws configure sso

# You'll be prompted for:
# SSO session name: my-sso-session
# SSO start URL: https://d-xxxxx.awsapps.com/start
# SSO region: us-east-1
# CLI default client region: us-east-1
# CLI default output format: json

# Step 6: This creates profile in ~/.aws/config
# [profile sso-profile]
# sso_start_url = https://d-xxxxx.awsapps.com/start
# sso_region = us-east-1
# sso_account_id = 123456789012
# sso_role_name = BedrockAccess
# region = us-east-1

# Step 7: Verify SSO setup
aws sso login --profile sso-profile
# Opens browser to authenticate

# Step 8: Verify credentials
aws sts get-caller-identity --profile sso-profile
```

#### Configuration in bedrock.config.yaml

```yaml
authentication:
  method: sso
  config:
    start_url: https://d-xxxxx.awsapps.com/start
    sso_region: us-east-1
    account_id: 123456789012
    role_name: BedrockAccess
    region: us-east-1
```

#### Advantages

- ✅ Enterprise single sign-on
- ✅ Centralized access control
- ✅ No long-lived credentials
- ✅ Compliance and audit friendly
- ✅ MFA integration

#### Disadvantages

- ❌ Requires AWS SSO setup
- ❌ Requires SSO provider integration
- ❌ May require manual browser login
- ❌ Not suitable for unattended automation

#### Multi-Account Setup

```bash
# In ~/.aws/config, create multiple profiles for different accounts:

[profile dev-sso]
sso_start_url = https://d-xxxxx.awsapps.com/start
sso_region = us-east-1
sso_account_id = 111111111111
sso_role_name = BedrockAccess
region = us-east-1

[profile prod-sso]
sso_start_url = https://d-xxxxx.awsapps.com/start
sso_region = us-east-1
sso_account_id = 222222222222
sso_role_name = BedrockAccessProd
region = us-east-1

# Login to all accounts:
aws sso login --profile dev-sso
aws sso login --profile prod-sso

# Switch between accounts:
AWS_PROFILE=dev-sso node bedrock-proxy.ts
AWS_PROFILE=prod-sso node bedrock-proxy.ts
```

---

## Comparison Table

| Feature | AWS CLI | IAM User | STS | SSO |
|---------|---------|----------|-----|-----|
| **Setup Time** | 10 min | 15 min | 30 min | 1-2 hr |
| **Credential Duration** | Long-lived | Long-lived | 1-12 hrs | 1 hr |
| **Security** | Medium | Low | High | Very High |
| **Best For** | Dev | CI/CD | Production | Enterprise |
| **MFA Support** | Yes | No | Yes | Yes |
| **Cross-Account** | No | No | Yes | Yes |
| **Cost** | Free | Free | Free | Free |
| **Complexity** | Low | Low | Medium | High |

---

## Environment Variables Reference

### All Methods Support These Variables

```bash
# AWS Region
AWS_REGION=us-east-1
AWS_DEFAULT_REGION=us-east-1

# Debug logging
DEBUG=true
AWS_SDK_LOG_LEVEL=debug
```

### IAM User Method Only

```bash
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
```

### STS Method Variables

```bash
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/BedrockRole
AWS_ROLE_SESSION_NAME=cursor-agent
AWS_ROLE_DURATION_SECONDS=3600
```

### SSO Method Variables

```bash
AWS_PROFILE=sso-profile  # Matches ~/.aws/config profile
```

---

## Testing Authentication

### Test Single Method

```bash
# Test AWS CLI
aws sts get-caller-identity

# Test IAM User (with env vars)
AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... \
  aws sts get-caller-identity

# Test STS
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/BedrockRole \
  --role-session-name test
```

### Test All Methods

```bash
# Use the built-in test:
npm run test:auth

# Or manually:
node -e "import('./src/gateway/auth-manager.ts').then(m => m.default.testAllMethods())"
```

---

## Troubleshooting

### "No valid credentials found"

```bash
# Check which method is configured
cat .claude/bedrock.config.yaml | grep -A2 authentication:

# For AWS CLI:
cat ~/.aws/credentials
aws sts get-caller-identity

# For IAM User:
echo $AWS_ACCESS_KEY_ID

# For STS:
aws sts get-caller-identity --query Arn

# For SSO:
aws sso login --profile sso-profile
```

### "Access Denied" errors

```bash
# 1. Verify user has Bedrock policy
aws iam get-user-policy \
  --user-name $(whoami) \
  --policy-name BedrockAccess

# 2. Check Bedrock is available in region
aws bedrock list-foundation-models --region us-east-1

# 3. Request Bedrock access if needed
# Go to: https://console.aws.amazon.com/bedrock/
# Click "Manage model access" → Request access
```

### "Credentials expired"

For STS and SSO, credentials automatically rotate. If stuck:

```bash
# STS: Get new credentials
aws sts assume-role ... --query 'Credentials'

# SSO: Re-login
aws sso login --profile sso-profile

# Clear cache:
rm -rf ~/.aws/sso/cache/
```

---

## Next Steps

After completing WOR-10 authentication methods:

1. ✅ All 4 authentication methods implemented
2. ✅ Configuration guide with examples
3. ✅ Testing and troubleshooting documented
4. ✅ Type-safe TypeScript implementation

**Proceed to WOR-11**: Cursor Integration & LLM Gateway (12 hours)

---

**Phase**: WOR-10 - Authentication Methods
**Status**: In Progress
**Estimated Completion**: 5 hours
**Created**: 2025-11-18
