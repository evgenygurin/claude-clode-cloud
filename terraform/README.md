# Terraform Infrastructure for AWS Bedrock

This directory contains Terraform configuration for provisioning AWS Bedrock infrastructure for Claude Code integration.

## Overview

The Terraform configuration creates:
- IAM roles and policies for Bedrock access
- CloudWatch log groups for monitoring
- Optional S3 bucket for configuration storage

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5.0 installed
3. IAM permissions to create IAM roles, CloudWatch logs, and S3 buckets

## Quick Start

### Development Environment

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Production Environment

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

## Configuration

### Variables

- `aws_region`: AWS region (us-east-1 or us-west-2)
- `environment`: Environment name (dev, staging, prod)
- `log_retention_days`: CloudWatch log retention period
- `create_config_bucket`: Whether to create S3 bucket for config

### Outputs

After applying, you'll get:
- IAM role ARN for Bedrock access
- CloudWatch log group name
- S3 bucket name (if created)
- AWS region and account ID

## IAM Permissions Required

The Terraform execution requires:
- `iam:CreateRole`
- `iam:AttachRolePolicy`
- `iam:CreatePolicy`
- `logs:CreateLogGroup`
- `s3:CreateBucket` (if creating config bucket)

## Bedrock Model Access

The IAM policy grants access to:
- `anthropic.claude-sonnet-4-5-20250929-v1:0`
- `anthropic.claude-haiku-4-5-20251001-v1:0`

## Remote State (Optional)

To use remote state with S3 backend, uncomment and configure in `main.tf`:

```hcl
backend "s3" {
  bucket = "your-terraform-state-bucket"
  key    = "claude-code-bedrock/terraform.tfstate"
  region = "us-east-1"
}
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources created by Terraform.

## Troubleshooting

### Issue: "Access Denied"

Ensure your AWS credentials have sufficient permissions.

### Issue: "Region not supported"

Bedrock is only available in specific regions. Use `us-east-1` or `us-west-2`.

### Issue: "Model not found"

Verify that Bedrock models are available in your AWS account. You may need to enable model access in the Bedrock console.

## Additional Resources

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
