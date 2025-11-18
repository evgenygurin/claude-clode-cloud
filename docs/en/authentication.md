# Authentication Guide

This guide covers all 4 authentication methods for AWS Bedrock.

## Method 1: AWS CLI Configuration

### Setup

```bash
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Output format (e.g., `json`)

### Usage

No additional configuration needed. Claude Code will automatically use AWS CLI credentials.

### Verification

```bash
aws sts get-caller-identity
```

## Method 2: Environment Variables

### Setup

```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_REGION="us-east-1"
```

### Usage

Add to your shell profile (`~/.bashrc`, `~/.zshrc`):

```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_REGION="us-east-1"
```

### Security

⚠️ **Never commit credentials to version control!**

Use environment variables or secret management tools.

## Method 3: SSO Profile

### Setup

```bash
aws configure sso
```

Follow the prompts to:
1. Set SSO start URL
2. Set SSO region
3. Set account ID
4. Set role name
5. Set profile name

### Usage

```bash
export AWS_PROFILE="your-profile-name"
```

### Login

```bash
aws sso login --profile your-profile-name
```

Credentials expire after a set period (typically 1 hour).

## Method 4: Bedrock API Keys

### Setup

Currently, Bedrock uses standard AWS credentials. API key support may be added in the future.

For now, use one of the other methods.

## Priority Order

Authentication is checked in this order:

1. `AWS_BEARER_TOKEN_BEDROCK` (if set)
2. `AWS_PROFILE` (if set)
3. `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` (if set)
4. AWS CLI default profile

## IAM Permissions Required

Your AWS credentials need these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ListFoundationModels",
        "bedrock:GetFoundationModel"
      ],
      "Resource": "*"
    }
  ]
}
```

## Troubleshooting

### "Access Denied"

- Check IAM permissions
- Verify credentials are valid
- Ensure Bedrock is enabled in your AWS account

### "Credentials Expired" (SSO)

```bash
aws sso login --profile your-profile
```

### "Profile Not Found"

- Verify profile name is correct
- Check `~/.aws/config` file
- Ensure SSO is configured correctly

## Best Practices

1. **Use IAM Roles** when possible (more secure)
2. **Rotate credentials** regularly
3. **Use SSO** for development (better security)
4. **Never commit credentials** to git
5. **Use environment variables** in CI/CD
6. **Monitor access** via CloudTrail

## Security Checklist

- ✅ Credentials stored securely
- ✅ IAM permissions minimal (principle of least privilege)
- ✅ Credentials rotated regularly
- ✅ No credentials in code or config files
- ✅ Access logged via CloudTrail
- ✅ MFA enabled for production accounts
