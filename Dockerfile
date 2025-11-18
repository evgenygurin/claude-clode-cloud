# ============================================================================
# Multi-stage Dockerfile for Claude Code Bedrock Integration
# ============================================================================

# Stage 1: Base image with Python and system dependencies
FROM python:3.12-slim as base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    awscli \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast Python package management
RUN pip install --no-cache-dir uv

# Set working directory
WORKDIR /app

# Stage 2: Dependencies
FROM base as dependencies

# Copy dependency files
COPY requirements.txt requirements-dev.txt ./

# Install dependencies using uv
RUN uv pip install --system -r requirements.txt

# Stage 3: Production image
FROM base as production

# Copy installed dependencies
COPY --from=dependencies /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=dependencies /usr/local/bin /usr/local/bin

# Copy application code
COPY src/ /app/src/
COPY scripts/ /app/scripts/

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command
CMD ["python", "-m", "src.gateway.main", "--host", "0.0.0.0", "--port", "8000"]
