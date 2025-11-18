# =============================================================================
# AWS Bedrock Integration - Main Terraform Configuration
# =============================================================================
# This configuration sets up AWS infrastructure for Claude Code integration
# with AWS Bedrock, enabling Cursor IDE to access Claude models via Bedrock
#
# Phase: WOR-8 - AWS Infrastructure Setup
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
  }

  # Uncomment to use S3 remote state (recommended for production)
  # backend "s3" {
  #   bucket         = "claude-code-bedrock-terraform-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "claude-code-bedrock-integration"
      Terraform   = "true"
      CreatedAt   = timestamp()
    }
  }
}

# =============================================================================
# 1. IAM Roles and Policies for Bedrock Access
# =============================================================================

# IAM Role for Lambda functions (if used)
resource "aws_iam_role" "bedrock_lambda_role" {
  name              = "claude-code-bedrock-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "bedrock-lambda-role"
  }
}

# Policy for Bedrock access
resource "aws_iam_role_policy" "bedrock_bedrock_policy" {
  name   = "claude-code-bedrock-access"
  role   = aws_iam_role.bedrock_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:GetFoundationModel",
          "bedrock:ListFoundationModels"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/*"
      },
      {
        Sid    = "BedrockAgents"
        Effect = "Allow"
        Action = [
          "bedrock-agent:GetAgent",
          "bedrock-agent:ListAgents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.bedrock_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# =============================================================================
# 2. KMS Key for Encryption (optional but recommended)
# =============================================================================

resource "aws_kms_key" "bedrock_key" {
  description             = "KMS key for Claude Code Bedrock integration"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "bedrock-kms-key"
  }
}

resource "aws_kms_alias" "bedrock_key_alias" {
  name          = "alias/claude-code-bedrock"
  target_key_id = aws_kms_key.bedrock_key.key_id
}

# =============================================================================
# 3. CloudWatch Log Group for Monitoring
# =============================================================================

resource "aws_cloudwatch_log_group" "bedrock_logs" {
  name              = "/aws/bedrock/claude-code-integration"
  retention_in_days = var.log_retention_days

  kms_key_id = aws_kms_key.bedrock_key.arn

  tags = {
    Name = "bedrock-logs"
  }
}

# =============================================================================
# 4. Outputs for Application Configuration
# =============================================================================

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role for Bedrock access"
  value       = aws_iam_role.bedrock_lambda_role.arn
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.bedrock_key.id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.bedrock_key.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for Bedrock operations"
  value       = aws_cloudwatch_log_group.bedrock_logs.name
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}
