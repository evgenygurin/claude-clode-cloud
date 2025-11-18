# ============================================================================
# Variables for AWS Bedrock Infrastructure
# ============================================================================

variable "aws_region" {
  description = "AWS region for Bedrock resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition = contains([
      "us-east-1",
      "us-west-2"
    ], var.aws_region)
    error_message = "Region must be us-east-1 or us-west-2 (Bedrock supported regions)."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "create_config_bucket" {
  description = "Whether to create S3 bucket for configuration storage"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
