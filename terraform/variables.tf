# =============================================================================
# Terraform Variables for AWS Bedrock Integration
# =============================================================================

variable "aws_region" {
  description = "AWS region for Bedrock deployment"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid AWS region format (e.g., us-east-1, eu-west-1)"
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days > 0 && var.log_retention_days <= 3653
    error_message = "Log retention must be between 1 and 3653 days"
  }
}

variable "enable_encryption" {
  description = "Enable KMS encryption for sensitive data"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Project = "claude-code-bedrock"
    Team    = "engineering"
  }
}
