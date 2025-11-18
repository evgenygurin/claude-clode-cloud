# API Documentation

Complete API reference for the LLM Gateway Proxy.

## Base URL

```
http://localhost:8000
```

## Authentication

Currently, no authentication is required for local development. In production, add API key authentication.

## Endpoints

### Health Check

```http
GET /health
```

**Response:**

```json
{
  "status": "healthy",
  "aws": "connected"
}
```

### List Models

```http
GET /v1/models
```

**Response:**

```json
{
  "object": "list",
  "data": [
    {
      "id": "anthropic.claude-sonnet-4-5-20250929-v1:0",
      "object": "model",
      "created": 1705593600,
      "owned_by": "anthropic"
    }
  ]
}
```

### Chat Completions

```http
POST /v1/chat/completions
```

**Request Body:**

```json
{
  "model": "claude-sonnet-4.5",
  "messages": [
    {
      "role": "user",
      "content": "Hello!"
    }
  ],
  "temperature": 1.0,
  "max_tokens": 4096,
  "stream": false
}
```

**Response:**

```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1705593600,
  "model": "claude-sonnet-4.5",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! How can I help you?"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 5,
    "completion_tokens": 10,
    "total_tokens": 15
  }
}
```

### Streaming

Set `"stream": true` in the request to enable streaming responses.

**Response Format (SSE):**

```
data: {"id":"chatcmpl-123","object":"chat.completion.chunk",...}

data: {"id":"chatcmpl-123","object":"chat.completion.chunk",...}

data: [DONE]
```

## Model Names

The gateway maps OpenAI-style model names to Bedrock model IDs:

- `claude-sonnet-4.5` → `anthropic.claude-sonnet-4-5-20250929-v1:0`
- `claude-haiku-4.5` → `anthropic.claude-haiku-4-5-20251001-v1:0`

You can also use Bedrock model IDs directly.

## Error Responses

```json
{
  "detail": "Error message"
}
```

**Status Codes:**

- `200` - Success
- `400` - Bad Request
- `500` - Internal Server Error

## Rate Limiting

Currently, no rate limiting is implemented. Add rate limiting in production.

## Examples

### Python

```python
import httpx

response = httpx.post(
    "http://localhost:8000/v1/chat/completions",
    json={
        "model": "claude-sonnet-4.5",
        "messages": [
            {"role": "user", "content": "Hello!"}
        ]
    }
)
print(response.json())
```

### cURL

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

### JavaScript

```javascript
const response = await fetch('http://localhost:8000/v1/chat/completions', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    model: 'claude-sonnet-4.5',
    messages: [
      { role: 'user', content: 'Hello!' }
    ]
  })
});

const data = await response.json();
console.log(data);
```
