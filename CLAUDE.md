# Claude Code Configuration Guide

This document provides specific instructions for configuring Claude Code to work with AWS Bedrock.

## Overview

Claude Code can be configured to use AWS Bedrock instead of the default Anthropic API. This allows you to leverage AWS infrastructure, regional availability, and potentially better pricing.

## Prerequisites

1. AWS Account with Bedrock access enabled
2. IAM permissions for Bedrock (`bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream`)
3. AWS credentials configured (see Authentication section)

## Environment Variables

### Required Variables

```bash
# Enable Bedrock usage
export CLAUDE_CODE_USE_BEDROCK=1

# AWS Region (must support Bedrock)
export AWS_REGION=us-east-1  # or us-west-2

# Claude Model IDs
export ANTHROPIC_MODEL=global.anthropic.claude-sonnet-4-5-20250929-v1:0
export ANTHROPIC_SMALL_FAST_MODEL=us.anthropic.claude-haiku-4-5-20251001-v1:0
```

### Optional Variables

```bash
# Token limits
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=4096
export MAX_THINKING_TOKENS=1024

# AWS Profile (if using SSO)
export AWS_PROFILE=bedrock-profile

# Bedrock API Key (alternative auth method)
export AWS_BEARER_TOKEN_BEDROCK=your-token
```

## Model IDs

### Available Regions

- **us-east-1** (N. Virginia)
- **us-west-2** (Oregon)

### Model Identifiers

**Sonnet 4.5:**
- Global: `global.anthropic.claude-sonnet-4-5-20250929-v1:0`
- US: `us.anthropic.claude-sonnet-4-5-20250929-v1:0`

**Haiku 4.5:**
- Global: `global.anthropic.claude-haiku-4-5-20251001-v1:0`
- US: `us.anthropic.claude-haiku-4-5-20251001-v1:0`

## Authentication

Claude Code supports multiple AWS authentication methods:

### Method 1: AWS CLI Configuration

```bash
aws configure
# Enter your Access Key ID
# Enter your Secret Access Key
# Enter default region (e.g., us-east-1)
# Enter output format (json)
```

### Method 2: Environment Variables

```bash
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_REGION=us-east-1
```

### Method 3: SSO Profile

```bash
aws configure sso
# Follow prompts to set up SSO

export AWS_PROFILE=your-sso-profile
```

### Method 4: Bedrock API Keys

```bash
export AWS_BEARER_TOKEN_BEDROCK=your-bedrock-api-key
```

## Verification

Test your configuration:

```bash
# Check AWS credentials
aws sts get-caller-identity

# List available Bedrock models
aws bedrock list-foundation-models \
  --region us-east-1 \
  --query 'modelSummaries[?providerName==`Anthropic`]'

# Test Bedrock access
aws bedrock invoke-model \
  --region us-east-1 \
  --model-id anthropic.claude-sonnet-4-5-20250929-v1:0 \
  --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":10,"messages":[{"role":"user","content":"Hello"}]}' \
  --cli-binary-format raw-in-base64-out
```

## Configuration Scripts

Use the provided scripts for easy setup:

```bash
# Setup script
./scripts/setup/configure-bedrock.sh

# Validation script
./scripts/validation/verify-config.sh

# Test connection
./scripts/validation/test-bedrock-connection.sh
```

## Troubleshooting

### Issue: "Access Denied"

**Solution**: Ensure IAM permissions include:
- `bedrock:InvokeModel`
- `bedrock:InvokeModelWithResponseStream`
- `bedrock:ListFoundationModels`

### Issue: "Model not found"

**Solution**: 
- Verify model ID is correct
- Check region supports the model
- Ensure model is available in your AWS account

### Issue: "Invalid credentials"

**Solution**:
- Verify AWS credentials are correct
- Check credential expiration (for SSO)
- Ensure credentials have Bedrock permissions

### Issue: "Region not supported"

**Solution**:
- Use `us-east-1` or `us-west-2`
- Check Bedrock availability in your region
- Update `AWS_REGION` environment variable

## Best Practices

1. **Use IAM Roles** when possible (more secure than access keys)
2. **Rotate credentials** regularly
3. **Monitor costs** using AWS Cost Explorer
4. **Use appropriate regions** for latency optimization
5. **Set token limits** to control costs

## Cost Optimization

- Use Haiku for simple tasks (lower cost)
- Use Sonnet for complex tasks (better quality)
- Set appropriate `MAX_OUTPUT_TOKENS`
- Monitor usage via AWS Cost Explorer
- Consider regional pricing differences

## Additional Resources

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Claude Code Documentation](https://code.claude.com/docs/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

---

For more information, see the main [README.md](README.md) and [docs/](docs/) directory.
