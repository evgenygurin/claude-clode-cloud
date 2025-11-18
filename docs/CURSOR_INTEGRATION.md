# Cursor IDE Integration - Phase WOR-11

Complete guide for integrating Claude Code + Bedrock with Cursor IDE.

## Overview

Cursor IDE is an advanced code editor with native AI integration. This phase enables seamless integration with your Claude Code + Bedrock setup.

**Estimated Setup Time**: 12 hours total (WOR-11)

**Components**:
1. LLM Gateway - Routes requests to optimal backend
2. Cursor Configuration - IDE settings
3. Integration Testing - Validation scripts
4. Performance Tuning - Optimization guide

---

## What is Cursor IDE?

Cursor is a modern code editor built on VSCode with integrated AI capabilities:

- **AI-Powered Code Completion**: Real-time suggestions powered by Claude
- **Natural Language Commands**: Type instructions in natural language
- **Multi-file Editing**: Edit multiple files in a single operation
- **Intelligent Refactoring**: Understand context across entire codebase
- **Built-in Terminal**: Integrated terminal with AI assistance

**Download**: https://www.cursor.com

---

## Installation & Setup

### Step 1: Install Cursor IDE

```bash
# macOS
brew install --cask cursor

# Or download from https://www.cursor.com/download

# Verify installation
cursor --version
```

### Step 2: Configure Custom AI Provider

**Method 1: Settings UI (Recommended)**

1. Open Cursor → Preferences (Cmd+,)
2. Search for "API Key"
3. Set the following:
   - **Provider**: OpenAI-compatible
   - **Base URL**: `http://localhost:3000`
   - **API Key**: (leave blank - proxy doesn't require auth)
   - **Model**: `claude-3-5-sonnet-20241022`

**Method 2: Configuration File**

Edit `.cursor/extensions/settings.json` or `~/.cursor/preferences.json`:

```json
{
  "apiBaseUrl": "http://localhost:3000",
  "apiKey": "",
  "model": "claude-3-5-sonnet-20241022",
  "provider": "custom",
  "temperature": 0.7,
  "maxTokens": 4096
}
```

### Step 3: Start the Proxy Server

In a terminal:

```bash
cd /path/to/claude-clode-cloud

# Install dependencies
npm install

# Start proxy server
npm run start:proxy

# Expected output:
# 🚀 Bedrock Proxy Server started on port 3000
# Region: us-east-1
# Health check: http://localhost:3000/health
# OpenAI-compatible API: http://localhost:3000/v1/chat/completions
```

### Step 4: Test Integration

In Cursor IDE, try these commands:

```bash
Cmd+K (or Ctrl+K) - Open command palette

Type: "Complete this function"
Select code → Run command

Type: "Explain this code"
Select code → Run command

Type: "Refactor for performance"
Select code → Run command
```

---

## LLM Gateway Architecture

```text
┌─────────────────────────────────────────────────────┐
│           Cursor IDE                                │
│   (User natural language commands)                  │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│    OpenAI-Compatible Proxy Server (Port 3000)       │
│   src/gateway/bedrock-proxy.ts                      │
│   - HTTP/HTTPS endpoint                            │
│   - Request translation                            │
│   - Authentication handling                        │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│    LLM Gateway (Smart Routing)                      │
│   src/gateway/llm-gateway.ts                        │
│   - Model selection                                │
│   - Cost optimization                              │
│   - Caching & metrics                              │
│   - Failover handling                              │
└────────────────┬────────────────────────────────────┘
                 │
        ┌────────┴────────┬──────────────────┐
        ▼                 ▼                  ▼
    ┌────────┐      ┌──────────┐      ┌──────────┐
    │Bedrock │      │OpenAI    │      │Local LLM │
    │Claude  │      │API       │      │(Optional)│
    └────────┘      └──────────┘      └──────────┘
```

### Gateway Features

**Model Selection**:
- Cost optimization (choose cheapest suitable model)
- Performance optimization (fastest response)
- Reliability optimization (most stable)
- Custom criteria (user-specified)

**Caching**:
- Request/response caching
- TTL-based expiration
- Cache hit metrics
- Memory management

**Metrics & Monitoring**:
- Request latency tracking
- Token usage monitoring
- Cost tracking per request
- Model performance analytics

**Failover**:
- Automatic fallback to secondary provider
- Health checks
- Graceful degradation
- Error recovery

---

## Configuration

### .claude/bedrock.config.yaml (Extended for Cursor)

```yaml
# Cursor IDE Integration
ide:
  editors:
    cursor:
      enabled: true
      auto_model_selection: true
      context_window: 200000
      preserve_context: true
      features:
        - code_completion
        - natural_language
        - multi_file_edit
        - refactoring
        - documentation

  # Code completion behavior
  completion:
    auto_complete: true
    suggestion_delay_ms: 500
    max_suggestions: 5
    debounce_ms: 300
    min_chars: 3

  # Inline documentation
  documentation:
    enabled: true
    inline_comments: true
    markdown_formatting: true
    auto_generate: false

  # Keyboard shortcuts (can be customized)
  shortcuts:
    quick_action: "cmd+k"
    chat: "cmd+l"
    inline_edit: "cmd+i"
    refactor: "cmd+r"
```

### LLM Gateway Configuration

```yaml
gateway:
  # Routing strategy
  default_provider: bedrock
  routing_strategy: cost-optimize  # or: direct, load-balance, failover

  # Model selection
  auto_select_model: true
  prefer_faster: false  # vs prefer_cheaper

  # Caching
  enable_caching: true
  cache_ttl_seconds: 3600
  cache_max_size_mb: 100

  # Metrics
  enable_metrics: true
  metrics_retention_hours: 24

  # Failover
  enable_failover: true
  fallback_providers:
    - openai
    - anthropic
  retry_attempts: 3
  retry_backoff_ms: 1000
```

---

## Usage Examples

### Example 1: Code Completion

**Scenario**: You're writing a function and want auto-completion

```typescript
// In Cursor IDE, start typing:
function calculateFibonacci(n: number): number {
  // Press Cmd+K for quick action
  // Or just wait for auto-complete suggestion
}

// Cursor suggests complete implementation with Claude 3.5 Sonnet
```

### Example 2: Natural Language Command

**Scenario**: You want to refactor a function for performance

```typescript
// Select function code
function slowSearch(arr: any[], target: any): number {
  for (let i = 0; i < arr.length; i++) {
    if (arr[i] === target) return i;
  }
  return -1;
}

// Open command (Cmd+K)
// Type: "Optimize this for large arrays using binary search"
// Cursor refactors with Claude's help
```

### Example 3: Multi-File Edit

**Scenario**: Update imports across multiple files

```bash
Open command (Cmd+K)
Type: "Update all imports from './old-path' to './new-path'"

Cursor:
1. Finds all affected files
2. Gets Claude's suggestions
3. Applies changes across entire project
4. Shows preview for approval
```

### Example 4: Documentation Generation

**Scenario**: Generate docs for a complex function

```typescript
// Place cursor in function
// Open command (Cmd+K)
// Type: "Generate comprehensive JSDoc documentation"

// Cursor generates:
/**
 * Searches for an element in a sorted array using binary search
 * @param arr - Sorted array of comparable elements
 * @param target - Element to search for
 * @returns Index of element (-1 if not found)
 * @complexity O(log n)
 * @example
 * const arr = [1, 3, 5, 7, 9];
 * const index = binarySearch(arr, 5); // returns 2
 */
```

---

## Performance Tuning

### Optimize Response Times

```yaml
# In .claude/bedrock.config.yaml

gateway:
  # Use faster model for auto-complete
  completion:
    model: claude-3-5-haiku-20241022  # 300ms avg latency

  # Use smarter model for refactoring
  refactoring:
    model: claude-3-5-sonnet-20241022  # 800ms avg latency

  # Use most capable for complex reasoning
  analysis:
    model: claude-3-opus-20240229  # 2000ms avg latency

# Adjust timeouts
requests:
  defaults:
    timeout_seconds: 30  # Auto-complete
    # vs
    timeout_seconds: 120  # Complex refactoring
```

### Reduce Costs

```yaml
gateway:
  routing_strategy: cost-optimize  # Always choose cheapest suitable model

  # Use Haiku for simple tasks
  auto_select_model: true

  # Enable caching for repeated requests
  enable_caching: true
  cache_ttl_seconds: 3600

  # Batch requests when possible
  batch_similar_requests: true
  batch_timeout_ms: 500
```

### Improve Reliability

```yaml
gateway:
  enable_failover: true
  fallback_providers:
    - bedrock  # Primary
    - openai   # Secondary (requires API key)
    - local    # Tertiary (optional local LLM)

  retry_attempts: 3
  retry_backoff_ms: 1000
  health_check_interval_seconds: 30
```

---

## Troubleshooting

### Issue: "Connection refused" on localhost:3000

**Solution**:
```bash
# Check if proxy is running
lsof -i :3000

# Start proxy if not running
cd /path/to/claude-clode-cloud
npm run start:proxy

# Check firewall
sudo pfctl -s nat  # macOS
sudo firewall-cmd --list-all  # Linux
```

### Issue: "API key required"

**Solution**:
- Leave API key blank in Cursor settings
- Proxy server doesn't require authentication
- Auth is handled via AWS credentials on server

### Issue: "Model not available"

**Solution**:
```bash
# Check available models
curl http://localhost:3000/v1/models

# Request Bedrock access if needed
# Go to: https://console.aws.amazon.com/bedrock/
# Click "Manage model access"
```

### Issue: "Slow responses"

**Solution**:
```yaml
# In .claude/bedrock.config.yaml

# Use faster model
gateway:
  completion:
    model: claude-3-5-haiku-20241022

# Increase timeout
requests:
  defaults:
    timeout_seconds: 60

# Check latency
# Call: http://localhost:3000/metrics
```

### Issue: "High costs"

**Solution**:
```yaml
# Enable cost optimization
gateway:
  routing_strategy: cost-optimize

# Use Haiku for simple tasks
  completion:
    model: claude-3-5-haiku-20241022  # 60% cheaper

# Cache responses
  enable_caching: true
  cache_ttl_seconds: 3600
```

---

## Advanced Features

### Custom Prompts

```typescript
// In Cursor settings, customize behavior:

{
  "system_prompt": "You are an expert full-stack developer...",
  "code_generation": {
    "style": "functional",
    "prefer_imports": "ES modules",
    "test_framework": "jest"
  },
  "refactoring": {
    "prefer_patterns": ["composition", "pure-functions"],
    "avoid": ["deep-nesting", "side-effects"]
  }
}
```

### Context Management

```typescript
// .cursor/context.json

{
  "project_rules": [
    "Always use TypeScript strict mode",
    "Follow Airbnb style guide",
    "Use 2-space indentation"
  ],
  "directories": {
    "api": "REST endpoints and middleware",
    "lib": "Reusable utilities",
    "components": "React components"
  },
  "excluded_patterns": [
    "node_modules/**",
    "dist/**",
    ".git/**"
  ]
}
```

### Integration with VS Code Extensions

```bash
# Install recommended extensions in Cursor

# Debugging
- Debugger for Chrome

# Testing
- Jest (official)

# Code quality
- ESLint
- Prettier

# Git
- GitLens
- Gitlens Supercharged

# AWS
- AWS Toolkit
```

---

## Keyboard Shortcuts Reference

| Action | Shortcut | Description |
|--------|----------|-------------|
| **Quick Action** | `Cmd+K` | Open command palette |
| **Chat** | `Cmd+L` | Open chat sidebar |
| **Inline Edit** | `Cmd+I` | Edit selected code inline |
| **Refactor** | `Cmd+R` | Refactor selected code |
| **Quick Fix** | `Cmd+.` | Show quick fixes |
| **Terminal** | `Cmd+J` | Toggle integrated terminal |

---

## Integration Testing

### Test Connection

```bash
# 1. Start proxy
npm run start:proxy

# 2. Test endpoint
curl http://localhost:3000/health

# 3. Test models
curl http://localhost:3000/v1/models

# 4. Test chat completion
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# 5. Open Cursor
cursor

# 6. Test code completion
# - Type code and observe suggestions
# - Use Cmd+K for refactoring
# - Check response times in metrics
```

### Performance Benchmarks

Expected performance with Bedrock backend:

| Task | Model | Latency | Tokens |
|------|-------|---------|--------|
| Code completion | Haiku | 200-500ms | 100-500 |
| Function refactor | Sonnet | 800-1200ms | 200-1000 |
| Architecture review | Opus | 2000-3000ms | 500-2000 |
| Bug analysis | Sonnet | 800-1500ms | 300-1500 |

---

## Metrics & Monitoring

### Check Gateway Metrics

```bash
# Get all metrics
curl http://localhost:3000/metrics | jq

# Example output:
{
  "total_requests": 245,
  "total_tokens": {
    "input": 45230,
    "output": 12450
  },
  "total_cost_usd": 0.182,
  "models_used": {
    "claude-3-5-sonnet-20241022": 180,
    "claude-3-5-haiku-20241022": 65
  },
  "cache_hit_rate": 0.23,
  "average_latency_ms": 850
}
```

### Monitor Performance

```bash
# Watch metrics in real-time
watch -n 5 'curl -s http://localhost:3000/metrics | jq ".total_cost_usd"'

# Log metrics to file
curl http://localhost:3000/metrics >> metrics.log &

# Analyze trends
jq '.total_cost_usd' metrics.log | tail -100 | awk '{sum+=$1} END {print "Avg:", sum/100}'
```

---

## Next Steps

After completing WOR-11 Cursor Integration:

1. ✅ LLM Gateway implementation
2. ✅ Model selection and routing
3. ✅ Cursor IDE configuration
4. ✅ Performance optimization
5. ✅ Integration testing

**Proceed to WOR-12**: Docker Containerization (8 hours)

---

**Phase**: WOR-11 - Cursor Integration & LLM Gateway
**Status**: In Progress
**Estimated Completion**: 12 hours
**Created**: 2025-11-18
