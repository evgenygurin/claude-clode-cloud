# ============================================================================
# AWS Bedrock Infrastructure for Claude Code Integration
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "claude-code-bedrock-terraform-state"
  #   key    = "terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "claude-code-bedrock"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# IAM Role for Bedrock Access
# ============================================================================

resource "aws_iam_role" "bedrock_access" {
  name = "claude-code-bedrock-access-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "claude-code-bedrock-access"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "bedrock_invoke" {
  name = "bedrock-invoke-policy-${var.environment}"
  role = aws_iam_role.bedrock_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel",
          "bedrock:ListInferenceProfiles"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0"
        ]
      }
    ]
  })
}

# ============================================================================
# CloudWatch Logs for Monitoring
# ============================================================================

resource "aws_cloudwatch_log_group" "bedrock_usage" {
  name              = "/aws/bedrock/claude-code-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "claude-code-bedrock-logs"
    Environment = var.environment
  }
}

# ============================================================================
# S3 Bucket for Configuration (Optional)
# ============================================================================

resource "aws_s3_bucket" "config" {
  count  = var.create_config_bucket ? 1 : 0
  bucket = "claude-code-config-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "claude-code-config"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "config" {
  count  = var.create_config_bucket ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count  = var.create_config_bucket ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "iam_role_arn" {
  description = "ARN of the IAM role for Bedrock access"
  value       = aws_iam_role.bedrock_access.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Bedrock usage"
  value       = aws_cloudwatch_log_group.bedrock_usage.name
}

output "config_bucket" {
  description = "S3 bucket for configuration (if created)"
  value       = var.create_config_bucket ? aws_s3_bucket.config[0].id : null
}

output "aws_region" {
  description = "AWS region used"
  value       = var.aws_region
}

output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}
