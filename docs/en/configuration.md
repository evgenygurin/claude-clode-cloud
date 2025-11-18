# Configuration Guide

Complete guide for configuring Claude Code with AWS Bedrock.

## Environment Variables

### Required Variables

```bash
# Enable Bedrock usage
CLAUDE_CODE_USE_BEDROCK=1

# AWS Region (must support Bedrock)
AWS_REGION=us-east-1  # or us-west-2

# Claude Model IDs
ANTHROPIC_MODEL=global.anthropic.claude-sonnet-4-5-20250929-v1:0
ANTHROPIC_SMALL_FAST_MODEL=us.anthropic.claude-haiku-4-5-20251001-v1:0
```

### Optional Variables

```bash
# Token limits
CLAUDE_CODE_MAX_OUTPUT_TOKENS=4096
MAX_THINKING_TOKENS=1024

# AWS Profile (for SSO)
AWS_PROFILE=bedrock-profile

# Bedrock API Key (alternative auth)
AWS_BEARER_TOKEN_BEDROCK=your-token
```

## Quick Setup

Use the provided setup script:

```bash
./scripts/setup/configure-bedrock.sh
```

This will:
1. Check prerequisites
2. Prompt for configuration values
3. Create `.env.bedrock` file
4. Verify Bedrock access

## Verification

Verify your configuration:

```bash
./scripts/validation/verify-config.sh
./scripts/validation/test-bedrock-connection.sh
```

## Authentication Methods

See [Authentication Guide](authentication.md) for details on all 4 methods.

## Model Configuration

### Available Models

**Sonnet 4.5:**
- Global: `global.anthropic.claude-sonnet-4-5-20250929-v1:0`
- US: `us.anthropic.claude-sonnet-4-5-20250929-v1:0`

**Haiku 4.5:**
- Global: `global.anthropic.claude-haiku-4-5-20251001-v1:0`
- US: `us.anthropic.claude-haiku-4-5-20251001-v1:0`

### Choosing Models

- **Sonnet**: Best quality, higher cost - use for complex tasks
- **Haiku**: Fast and cost-effective - use for simple tasks

## Regional Configuration

Bedrock is available in:
- `us-east-1` (N. Virginia) - Recommended
- `us-west-2` (Oregon)

Choose based on:
- Latency requirements
- Cost optimization
- Data residency requirements

## Troubleshooting

See [Troubleshooting Guide](troubleshooting.md) for common issues.
