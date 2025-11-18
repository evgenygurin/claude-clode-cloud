# Cursor Integration Guide

Since Cursor IDE doesn't have native AWS Bedrock support, we provide three workaround solutions.

## Option A: Separate CLI (Simple)

Use Cursor for editing code, and run Claude Code CLI in a separate terminal.

### Setup

1. Configure Bedrock (see [Configuration Guide](configuration.md))
2. Use Cursor for code editing
3. Run Claude Code commands in terminal:

```bash
# Example: Generate code
claude-code generate --prompt "Add error handling to this function"
```

### Pros
- Simple setup
- No proxy needed
- Direct Bedrock access

### Cons
- Not integrated into Cursor
- Manual workflow
- No inline suggestions

## Option B: LLM Gateway Proxy (Recommended) ⭐

Run an OpenAI-compatible proxy that translates requests to AWS Bedrock.

### Architecture

```
Cursor IDE → LLM Gateway (OpenAI API) → AWS Bedrock
```

### Setup

1. **Start the Gateway**

```bash
# Using Docker
docker-compose up -d

# Or directly
python -m src.gateway.main --host 0.0.0.0 --port 8000
```

2. **Configure Cursor**

In Cursor settings, point to the gateway:

```json
{
  "claude": {
    "api_base": "http://localhost:8000/v1",
    "api_key": "not-needed"
  }
}
```

3. **Verify Connection**

```bash
curl http://localhost:8000/health
```

### API Endpoints

The gateway provides OpenAI-compatible endpoints:

- `GET /v1/models` - List available models
- `POST /v1/chat/completions` - Chat completions
- `GET /health` - Health check

### Example Request

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4.5",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

### Pros
- ✅ Seamless integration with Cursor
- ✅ OpenAI-compatible API
- ✅ Full control over requests
- ✅ Can add custom features

### Cons
- Requires running a proxy server
- Additional network hop

## Option C: Monitor Cursor Updates

Wait for native Bedrock support in future Cursor releases.

### Current Status

As of 2025-01-18, Cursor doesn't have native Bedrock support.

### Monitoring

- Check Cursor release notes
- Monitor Cursor GitHub issues
- Watch for Bedrock integration announcements

## Recommendation

**Use Option B (LLM Gateway Proxy)** for the best experience:

1. Full integration with Cursor
2. Production-ready solution
3. Easy to deploy and maintain
4. Can be extended with custom features

## Deployment

### Local Development

```bash
docker-compose up -d
```

### Production

Deploy the gateway to:
- AWS ECS/Fargate
- Kubernetes
- EC2 instance
- Lambda (with API Gateway)

See [Deployment Guide](deployment.md) for details.

## Troubleshooting

### Gateway not responding

```bash
# Check if running
docker ps | grep gateway

# Check logs
docker logs claude-code-gateway

# Test connection
curl http://localhost:8000/health
```

### Cursor can't connect

1. Verify gateway is running
2. Check Cursor API configuration
3. Verify network connectivity
4. Check firewall rules

### Authentication errors

1. Verify AWS credentials
2. Check IAM permissions
3. Test Bedrock access directly:

```bash
aws bedrock list-foundation-models --region us-east-1
```

## Advanced Configuration

### Custom Model Mapping

Edit `src/gateway/server.py` to customize model name mapping.

### Rate Limiting

Add rate limiting middleware to prevent abuse.

### Caching

Implement response caching for common requests.

### Monitoring

Integrate with CloudWatch for metrics and logging.

## Security Considerations

1. **Restrict CORS** - Only allow Cursor domains in production
2. **Use HTTPS** - Deploy behind a load balancer with SSL
3. **Authentication** - Add API key authentication if needed
4. **Rate Limiting** - Prevent abuse
5. **Logging** - Monitor all requests

## Next Steps

1. Deploy the gateway (see [Deployment Guide](deployment.md))
2. Configure Cursor to use the gateway
3. Test the integration
4. Monitor usage and costs
