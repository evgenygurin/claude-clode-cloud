# ============================================================================
# Production Environment Configuration
# ============================================================================

aws_region          = "us-east-1"
environment         = "prod"
log_retention_days  = 90
create_config_bucket = true

tags = {
  Environment = "production"
  Project     = "claude-code-bedrock"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
}
