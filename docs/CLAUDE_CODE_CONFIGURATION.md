# Claude Code Configuration - Phase WOR-9

Complete guide for configuring Claude Code IDE to work with AWS Bedrock.

## Overview

Phase WOR-9 sets up Claude Code IDE to seamlessly access Claude models through AWS Bedrock, enabling:
- Native Claude Code integration with Bedrock
- OpenAI-compatible API proxy for maximum compatibility
- Token tracking and cost optimization
- Multiple authentication methods

**Estimated Time**: 6 hours
**Status**: In Progress

## What is Claude Code?

Claude Code is an AI-powered coding assistant that integrates directly into your development environment. When configured with Bedrock, it provides:

- **Real-time code completion** with Claude 3.5 Sonnet
- **Intelligent refactoring** suggestions
- **Documentation generation** for complex functions
- **Bug detection and fixes** with detailed explanations
- **Architecture review** and improvement suggestions

## Prerequisites

Before configuring Claude Code:

1. **AWS Account Setup** (WOR-8) ✓ Completed
   - Bedrock access verified
   - Credentials configured
   - IAM roles created

2. **Node.js 18+** (for proxy server)
   ```bash
   node --version  # Should be v18.0.0 or higher
   ```

3. **Cursor IDE or VSCode** with Claude extension

## Installation & Setup

### Step 1: Install Proxy Server Dependencies

The proxy server translates OpenAI API calls to Bedrock:

```bash
# Install npm dependencies
npm install

# Dependencies include:
# - express: Web server for proxy
# - @aws-sdk/client-bedrock-runtime: AWS Bedrock access
# - @anthropic-ai/sdk: Anthropic SDK (optional)
# - cors: Cross-origin support
# - dotenv: Environment variable management
```

### Step 2: Configure Environment Variables

Create `.env` file with Bedrock credentials:

```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# Proxy Server
PORT=3000
DEBUG=false

# Optional: For cost tracking
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
LINEAR_API_KEY=lin_pat_...
```

Or use AWS CLI credentials:

```bash
aws configure
# Proxy will automatically use ~/.aws/credentials
```

### Step 3: Start Proxy Server

```bash
# Development mode (hot reload)
npm run start:proxy

# Or directly with Node.js
node src/gateway/bedrock-proxy.ts

# Expected output:
# 🚀 Bedrock Proxy Server started on port 3000
# Region: us-east-1
# Debug mode: false
# Health check: http://localhost:3000/health
# OpenAI-compatible API: http://localhost:3000/v1/chat/completions
```

### Step 4: Verify Proxy is Running

```bash
# Health check
curl http://localhost:3000/health

# Expected response:
# {
#   "status": "healthy",
#   "timestamp": "2025-11-18T12:00:00Z",
#   "region": "us-east-1"
# }

# List available models
curl http://localhost:3000/v1/models | jq
```

## Configure Cursor IDE

### For Cursor (Recommended)

1. **Open Cursor Settings** (Cmd+, on Mac, Ctrl+, on Linux/Windows)

2. **Search for "API Key"** and configure:
   ```bash
   Provider: Custom (OpenAI-compatible)
   API Key: (leave empty for local proxy)
   Base URL: http://localhost:3000
   Model: claude-3-5-sonnet-20241022
   ```

3. **Alternative: Use Settings UI**
   - Go to: **Cursor Settings** > **Models** > **Add Custom Model**
   - Provider: OpenAI-compatible
   - Base URL: `http://localhost:3000`
   - API Key: (leave blank - proxy doesn't require auth)
   - Model: Select from dropdown

### For VSCode + Claude Extension

1. **Install Claude Extension**
   - Open Extensions (Cmd+Shift+X)
   - Search: "Anthropic Claude"
   - Click Install

2. **Configure Extension Settings**
   ```json
   {
     "claude.apiBaseUrl": "http://localhost:3000",
     "claude.model": "claude-3-5-sonnet-20241022",
     "claude.temperature": 0.7,
     "claude.maxTokens": 4096
   }
   ```

## Configuration File Structure

### `.claude/bedrock.config.yaml`

Main configuration file with all settings:

```yaml
# Core Bedrock configuration
bedrock:
  region: us-east-1
  models: [...]

# Proxy server settings
proxy:
  host: localhost
  port: 3000

# Authentication method
authentication:
  method: aws_cli  # or iam_user, sts, sso

# Token tracking
tokens:
  tracking_enabled: true
  daily_limits: {...}

# Cost management
cost_tracking:
  enabled: true
  monthly_budget: 100.0
```

## Available Models

### Claude 3.5 Sonnet (Recommended)
- **Best for**: Code generation, complex reasoning
- **Context**: 200K tokens
- **Speed**: Fast
- **Cost**: $3/$15 per 1M tokens (input/output)
- **Use cases**:
  - Code completion
  - Refactoring
  - Architecture review
  - Documentation

```bash
Model ID: claude-3-5-sonnet-20241022
OpenAI ID: gpt-4
Bedrock ID: anthropic.claude-3-5-sonnet-20241022-v2:0
```

### Claude 3.5 Haiku (Budget-friendly)
- **Best for**: Quick edits, simple tasks
- **Context**: 200K tokens
- **Speed**: Very fast
- **Cost**: $0.8/$2.4 per 1M tokens
- **Use cases**:
  - Quick completions
  - Simple debugging
  - Testing

```bash
Model ID: claude-3-5-haiku-20241022
OpenAI ID: gpt-3.5-turbo
Bedrock ID: anthropic.claude-3-5-haiku-20241022-v1:0
```

### Claude 3 Opus (Most Capable)
- **Best for**: Deep analysis, research
- **Context**: 200K tokens
- **Speed**: Slower
- **Cost**: $15/$75 per 1M tokens
- **Use cases**:
  - Complex architecture decisions
  - Deep code analysis
  - Research tasks

```bash
Model ID: claude-3-opus-20240229
Bedrock ID: anthropic.claude-3-opus-20240229-v1:0
```

## Testing Integration

### Run Integration Tests

```bash
# Make test script executable
chmod +x scripts/test-claude-bedrock.sh

# Run comprehensive tests
./scripts/test-claude-bedrock.sh

# Expected output shows:
# ✓ AWS CLI installed
# ✓ AWS credentials valid
# ✓ Bedrock available in region
# ✓ Claude models available
# ✓ Proxy server running
# ✓ OpenAI API compatibility
# ✓ Model invocation successful
```

### Manual API Testing

```bash
# Test proxy with curl
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
      {
        "role": "user",
        "content": "Hello, who are you?"
      }
    ],
    "max_tokens": 100
  }'

# Expected response:
# {
#   "id": "chatcmpl-...",
#   "object": "chat.completion",
#   "created": 1234567890,
#   "model": "claude-3-5-sonnet-20241022",
#   "choices": [...]
# }
```

## Token Management

### Understanding Tokens

Tokens are chunks of text used by Claude models:
- Average word = 1.3 tokens
- Average code line = 15-25 tokens
- 1M tokens = approximately $3-15 depending on model

### Token Tracking

Enable automatic token tracking:

```yaml
tokens:
  tracking_enabled: true
  tracking_endpoint: http://localhost:3000/metrics

  daily_limits:
    enabled: true
    input_tokens: 1000000
    output_tokens: 500000

  alerts:
    enabled: true
    warning_threshold_percent: 80
```

### Monitor Token Usage

```bash
# Get metrics from proxy
curl http://localhost:3000/metrics | jq .

# Example output:
# {
#   "total_requests": 142,
#   "total_tokens_input": 45230,
#   "total_tokens_output": 12450,
#   "total_cost_usd": 0.18,
#   "models_used": ["claude-3-5-sonnet", "claude-3-5-haiku"]
# }
```

## Cost Optimization

### Budget Management

Set monthly budget and alerts:

```yaml
cost_tracking:
  enabled: true
  currency: USD
  monthly_budget: 100.0
  alert_on_budget_exceeded: true
```

### Cost Reduction Strategies

1. **Use Haiku for Simple Tasks**
   - ~40% cheaper than Sonnet
   - Sufficient for quick edits and completions

2. **Optimize Prompt Engineering**
   - Clearer prompts = fewer tokens needed
   - Be specific about expected output format
   - Avoid redundant context

3. **Cache Common Contexts**
   - Bedrock supports prompt caching
   - Reuse of context reduces token costs
   - Cache hit = 90% cost reduction

4. **Batch Processing**
   - Process similar requests together
   - Use cost-effective models in batch mode

### Cost Monitoring

```bash
# View daily cost breakdown
curl http://localhost:3000/metrics | jq '.daily_breakdown'

# Set up Slack alerts for cost thresholds
# Configure SLACK_WEBHOOK_URL in .env
```

## Troubleshooting

### Issue: "Connection refused" on localhost:3000

**Solution**: Proxy server not running

```bash
# Check if process is running
ps aux | grep bedrock-proxy

# Start proxy
npm run start:proxy

# Check firewall
sudo lsof -i :3000
```

### Issue: "No Claude models available"

**Solution**: Request Bedrock access

1. Go to: https://console.aws.amazon.com/bedrock/
2. Click "Manage model access"
3. Select Claude models
4. Request access
5. Wait for approval (usually instant)

### Issue: "Access Denied" errors

**Solution**: Check IAM permissions

```bash
# Verify IAM role has Bedrock permissions
aws iam get-role-policy --role-name claude-code-bedrock-lambda-role \
  --policy-name BedrockAccess

# Check current user permissions
aws iam get-user-policy --user-name $(whoami) \
  --policy-name bedrock-access
```

### Issue: High token usage

**Solution**: Optimize model selection

```bash
# Use Haiku for simple tasks
# Use Sonnet only for complex reasoning
# Implement prompt caching for repeated tasks
```

## Advanced Configuration

### Custom Model Mapping

Add custom model names in config:

```yaml
bedrock:
  models:
    - id: my-custom-claude
      bedrock_id: anthropic.claude-3-5-sonnet-20241022-v2:0
      display_name: "My Custom Claude"
      max_tokens: 200000
```

### SSL/TLS for Production

```yaml
security:
  tls:
    enabled: true
    cert_file: /path/to/cert.pem
    key_file: /path/to/key.pem
```

### Custom Request Signing

```yaml
security:
  sign_requests: true
  signature_algorithm: aws4  # AWS Signature Version 4
```

## Performance Tuning

### Connection Pooling

```yaml
advanced:
  connection_pool:
    min_size: 2
    max_size: 10
    idle_timeout_seconds: 300
```

### Streaming Responses

Enable streaming for large outputs:

```yaml
advanced:
  streaming:
    enabled: true
    chunk_size_tokens: 256
```

## Integration Examples

### Example 1: Code Completion

```bash
# Use Claude for code completion
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
      {
        "role": "system",
        "content": "You are an expert Python developer"
      },
      {
        "role": "user",
        "content": "Write a function to calculate fibonacci numbers"
      }
    ],
    "max_tokens": 1024
  }'
```

### Example 2: Code Review

```bash
# Use Claude for code review
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
      {
        "role": "user",
        "content": "Review this code for security issues:\n\n[paste code here]"
      }
    ],
    "max_tokens": 2048
  }'
```

## Next Steps

After completing WOR-9:

1. ✅ Claude Code configured for Bedrock
2. ✅ Proxy server running locally
3. ✅ Models tested and verified
4. ✅ Token tracking enabled
5. ✅ Cost monitoring configured

**Proceed to WOR-10**: Authentication Methods

## Related Documentation

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Claude Code Features](https://code.claude.com/docs/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)

## Support

For issues:

1. Check `scripts/test-claude-bedrock.sh` output
2. Review `.claude/bedrock.config.yaml` settings
3. Check logs: `~/.claude/logs/bedrock.log`
4. Post in Linear issue WOR-9

---

**Phase**: WOR-9 - Claude Code Configuration
**Status**: In Progress
**Estimated Completion**: 6 hours
**Created**: 2025-11-18
