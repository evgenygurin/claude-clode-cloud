# AWS Infrastructure Setup - Phase WOR-8

This document provides step-by-step instructions for setting up AWS infrastructure for Claude Code and AWS Bedrock integration.

## Overview

Phase WOR-8 establishes the foundational AWS infrastructure needed to:
- Access Claude models through AWS Bedrock
- Manage credentials and encryption
- Enable monitoring and logging
- Prepare for LLM Gateway proxy deployment (Phase WOR-11)

**Estimated Time**: 8 hours
**Status**: In Progress

## Prerequisites

Before starting, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   brew install awscli  # macOS
   aws --version         # Verify installation
   ```
3. **Terraform** installed (v1.5 or later)
   ```bash
   brew install terraform
   terraform version
   ```
4. **jq** for JSON processing
   ```bash
   brew install jq
   ```

## Step 1: Configure AWS CLI

### 1.1 Initial Configuration

```bash
aws configure
```

You'll be prompted for:
- **AWS Access Key ID**: Your access key
- **AWS Secret Access Key**: Your secret key
- **Default region**: Choose one where Bedrock is available (see below)
- **Default output format**: json

### 1.2 Available Regions for Bedrock

Bedrock is available in the following regions:

| Region Name | Region Code | AWS Console |
|-------------|------------|-------------|
| US East (N. Virginia) | us-east-1 | https://console.aws.amazon.com/bedrock/ |
| US West (Oregon) | us-west-2 | https://console.aws.amazon.com/bedrock/ |
| EU (Ireland) | eu-west-1 | https://console.aws.amazon.com/bedrock/ |
| AP Southeast (Singapore) | ap-southeast-1 | https://console.aws.amazon.com/bedrock/ |

**Recommendation**: Use `us-east-1` for lowest latency and widest model availability.

### 1.3 Verify Configuration

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

## Step 2: Enable Bedrock Model Access

### 2.1 Check Available Models

```bash
aws bedrock list-foundation-models --region us-east-1
```

### 2.2 Request Model Access (if needed)

If models are not available, request access via AWS Console:

1. Go to: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/foundation-models
2. Click "Manage model access"
3. Select Claude models (Claude 3 Opus, Sonnet, Haiku)
4. Click "Request access"
5. Wait for approval (usually instant or within 24 hours)

### 2.3 Run Setup Script

```bash
chmod +x scripts/aws-bedrock-setup.sh
./scripts/aws-bedrock-setup.sh
```

This script will:
- Verify AWS credentials
- Check Bedrock availability in your region
- List available models
- Validate access

## Step 3: Deploy Infrastructure with Terraform

### 3.1 Initialize Terraform

```bash
cd terraform
terraform init
```

This downloads required providers and initializes the working directory.

### 3.2 Configure Variables

Copy and customize the variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region        = "us-east-1"
environment       = "dev"
log_retention_days = 30
enable_encryption  = true

tags = {
  Project     = "claude-code-bedrock"
  Team        = "engineering"
  Owner       = "your-team@example.com"
}
```

### 3.3 Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the proposed changes. You should see:
- 1 KMS key for encryption
- 1 KMS alias
- 1 IAM role for Lambda
- 2 IAM policies
- 1 CloudWatch log group

Example output:
```text
Plan: 6 to add, 0 to change, 0 to destroy.
```

### 3.4 Apply Configuration

```bash
terraform apply tfplan
```

This creates all AWS resources. Terraform will output:

```text
Outputs:

lambda_role_arn = "arn:aws:iam::123456789012:role/claude-code-bedrock-lambda-role"
kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
log_group_name = "/aws/bedrock/claude-code-integration"
aws_region = "us-east-1"
```

### 3.5 Save Terraform State

**Important**: Keep your Terraform state file secure!

```bash
# View what was created
terraform state list

# Output values for later use
terraform output
```

## Step 4: Verify Infrastructure

### 4.1 Check IAM Role

```bash
aws iam get-role --role-name claude-code-bedrock-lambda-role
```

### 4.2 Check KMS Key

```bash
aws kms describe-key --key-id alias/claude-code-bedrock
```

### 4.3 Check CloudWatch Log Group

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/bedrock/claude-code-integration"
```

## Step 5: Create Bedrock-Specific IAM User (Optional)

For additional security, create a dedicated IAM user for Bedrock API calls:

```bash
# Run interactive setup
./scripts/aws-bedrock-setup.sh
# When prompted, select option to create IAM user
```

This will:
1. Create IAM user: `cursor-bedrock-agent`
2. Generate access key and secret
3. Attach Bedrock-specific permissions
4. Output credentials for safekeeping

## Cost Optimization

### Expected Costs

- **KMS**: ~$1/month for the key + usage costs
- **CloudWatch Logs**: ~$0.50/month for 30-day retention
- **IAM**: Free (included in AWS account)
- **Bedrock**: Pay-per-token (varies by model)

### Cost Monitoring

```bash
# Enable CloudWatch cost anomaly detection
aws ce update-cost-category-definition --region us-east-1 ...

# Or use AWS Cost Explorer dashboard:
# https://console.aws.amazon.com/cost-management/home
```

## Troubleshooting

### Issue: "User is not authorized to perform: bedrock:ListFoundationModels"

**Solution**: Check that you've requested model access in the Bedrock console.

```bash
# Verify your IAM permissions
aws iam get-user-policy --user-name $(whoami) --policy-name <policy-name>
```

### Issue: "No Bedrock models available"

**Solution**: Wait 24 hours after requesting access, or switch to a supported region.

```bash
# List available regions
aws ec2 describe-regions --query 'Regions[*].[RegionName]' --output text
```

### Issue: "Terraform Error: error reading S3 Bucket"

**Solution**: State file might be corrupted. Re-initialize:

```bash
rm terraform.tfstate terraform.tfstate.*
terraform init
terraform plan
```

## Next Steps

After completing WOR-8:

1. ✅ AWS credentials configured
2. ✅ Bedrock access verified
3. ✅ Infrastructure deployed via Terraform
4. ✅ KMS encryption enabled
5. ✅ Monitoring set up

**Proceed to WOR-9**: Claude Code Configuration

## Related Phases

- **WOR-7**: Project Planning ← Current Phase Dependencies
- **WOR-8**: AWS Infrastructure Setup ← YOU ARE HERE
- **WOR-9**: Claude Code Configuration → Next Phase
- **WOR-10**: Authentication Methods
- **WOR-11**: Cursor Integration & LLM Gateway
- **WOR-12**: Docker Containerization
- **WOR-13**: CI/CD Pipeline
- **WOR-14**: Documentation
- **WOR-15**: Monitoring & Cost Optimization
- **WOR-16**: Linear + Cursor Agent Configuration

## Resources

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [KMS Encryption Guide](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)

## Support

For issues or questions:

1. Check Linear issue WOR-8 for updates
2. Review AWS Console Bedrock section
3. Check CloudWatch logs: `/aws/bedrock/claude-code-integration`
4. Post in project discussions

---

**Phase**: WOR-8 - AWS Infrastructure Setup
**Status**: In Progress
**Estimated Completion**: 8 hours
**Created**: 2025-11-18
