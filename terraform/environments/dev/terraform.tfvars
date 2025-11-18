# ============================================================================
# Development Environment Configuration
# ============================================================================

aws_region          = "us-east-1"
environment         = "dev"
log_retention_days  = 7
create_config_bucket = false

tags = {
  Environment = "development"
  Project     = "claude-code-bedrock"
  ManagedBy   = "terraform"
}
