# 🚀 Claude Code AWS Bedrock Integration for Cursor IDE

Production-ready repository for integrating Claude Code with AWS Bedrock, providing access to Claude models (Sonnet 4.5, Haiku 4.5) through AWS infrastructure for use in Cursor IDE.

## 📋 Project Overview

This project enables seamless integration between Claude Code and AWS Bedrock, allowing developers to use Claude models through AWS infrastructure. The entire implementation is automated through Cursor Agent in Linear.

## 🎯 Features

- ✅ **AWS Bedrock Integration** - Full Terraform IaC setup
- ✅ **Multiple Authentication Methods** - AWS CLI, Environment Variables, SSO, API Keys
- ✅ **LLM Gateway Proxy** - OpenAI-compatible API for Cursor integration
- ✅ **Docker Containerization** - Production-ready containers
- ✅ **CI/CD Pipeline** - Automated testing and deployment
- ✅ **Monitoring & Cost Tracking** - Token usage and AWS cost optimization
- ✅ **Linear Integration** - Automated task management via GraphQL API

## 🏗️ Architecture

```
┌─────────────┐
│   Cursor    │
│     IDE     │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  LLM Gateway    │  ← OpenAI-compatible proxy
│     Proxy       │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│  AWS Bedrock    │
│  (Claude API)   │
└─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- AWS Account with Bedrock access
- AWS CLI configured
- Docker and Docker Compose
- Python 3.12+
- Terraform 1.5+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/evgenygurin/claude-clode-cloud.git
   cd claude-clode-cloud
   ```

2. **Set up AWS credentials**
   ```bash
   # Method 1: AWS CLI
   aws configure
   
   # Method 2: Environment Variables
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   export AWS_REGION="us-east-1"
   ```

3. **Deploy infrastructure**
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform plan
   terraform apply
   ```

4. **Start LLM Gateway**
   ```bash
   docker-compose up -d
   ```

5. **Configure Cursor**
   ```bash
   # Set environment variables
   export CLAUDE_CODE_USE_BEDROCK=1
   export AWS_REGION=us-east-1
   export ANTHROPIC_MODEL=global.anthropic.claude-sonnet-4-5-20250929-v1:0
   ```

## 📁 Project Structure

```
.
├── terraform/          # Infrastructure as Code
│   ├── modules/        # Reusable Terraform modules
│   └── environments/   # Environment-specific configs
├── src/
│   ├── gateway/        # LLM Gateway Proxy
│   ├── auth/           # Authentication handlers
│   ├── monitoring/     # Monitoring and metrics
│   └── linear_integration/  # Linear API integration
├── scripts/            # Setup and deployment scripts
├── tests/              # Unit and integration tests
├── docs/               # Documentation (EN + RU)
└── .github/workflows/  # CI/CD pipelines
```

## 🔧 Configuration

### Environment Variables

```bash
# AWS Configuration
CLAUDE_CODE_USE_BEDROCK=1
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret

# Claude Models
ANTHROPIC_MODEL=global.anthropic.claude-sonnet-4-5-20250929-v1:0
ANTHROPIC_SMALL_FAST_MODEL=us.anthropic.claude-haiku-4-5-20251001-v1:0

# Token Limits
CLAUDE_CODE_MAX_OUTPUT_TOKENS=4096
MAX_THINKING_TOKENS=1024
```

See [docs/en/configuration.md](docs/en/configuration.md) for detailed configuration options.

## 🔐 Authentication Methods

The project supports 4 authentication methods:

1. **AWS CLI Configuration** (`aws configure`)
2. **Environment Variables** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
3. **SSO Profile** (`AWS_PROFILE`)
4. **Bedrock API Keys** (`AWS_BEARER_TOKEN_BEDROCK`)

See [docs/en/authentication.md](docs/en/authentication.md) for details.

## 🔄 Cursor Integration

Since Cursor doesn't have native AWS Bedrock support, we provide an **LLM Gateway Proxy** that implements an OpenAI-compatible API, allowing Cursor to connect seamlessly.

### Option A: Separate CLI
Use Cursor for editing + CLI in terminal for Claude Code.

### Option B: LLM Gateway Proxy (Recommended)
OpenAI-compatible proxy that translates requests to AWS Bedrock.

### Option C: Monitor Cursor Updates
Wait for native Bedrock support in future Cursor releases.

See [docs/en/cursor-integration.md](docs/en/cursor-integration.md) for implementation details.

## 🐳 Docker

```bash
# Build
docker build -t claude-code-bedrock .

# Run
docker run -d \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  -e AWS_REGION=us-east-1 \
  -p 8000:8000 \
  claude-code-bedrock

# Or use docker-compose
docker-compose up -d
```

## 🧪 Testing

```bash
# Unit tests
pytest tests/unit/

# Integration tests
pytest tests/integration/

# All tests
pytest tests/
```

## 📊 Monitoring

- Token usage tracking
- AWS Cost Explorer integration
- Performance metrics
- Regional cost optimization

See [docs/en/monitoring.md](docs/en/monitoring.md) for details.

## 📚 Documentation

- [English Documentation](docs/en/)
- [Русская Документация](docs/ru/)
- [CLAUDE.md](CLAUDE.md) - Claude Code specific documentation
- [API Documentation](docs/en/api.md)

## 🤖 Linear Integration

This project includes automated Linear integration for task management:

- Automatic issue tracking
- Progress updates via GraphQL API
- Real-time status synchronization
- Automated PR creation

See [linear-automation/](linear-automation/) for GraphQL queries and setup.

## 🛠️ Development

### Setup Development Environment

```bash
# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Install pre-commit hooks
pre-commit install

# Run linters
ruff check src/
mypy src/
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🔗 Links

- **GitHub Repository**: https://github.com/evgenygurin/claude-clode-cloud
- **Claude Code Docs**: https://code.claude.com/docs/
- **AWS Bedrock Docs**: https://aws.amazon.com/bedrock/
- **Linear Project**: https://linear.app/workdev

## 🙏 Acknowledgments

- Claude Code team for the excellent tooling
- AWS Bedrock for model hosting
- Cursor team for the IDE

---

**Status**: 🚧 In Development  
**Version**: 1.0.0  
**Last Updated**: 2025-01-18
