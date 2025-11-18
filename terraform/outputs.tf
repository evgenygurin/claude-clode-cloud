# ============================================================================
# Outputs for AWS Bedrock Infrastructure
# ============================================================================

output "iam_role_arn" {
  description = "ARN of the IAM role for Bedrock access"
  value       = aws_iam_role.bedrock_access.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name for Bedrock usage monitoring"
  value       = aws_cloudwatch_log_group.bedrock_usage.name
}

output "config_bucket_name" {
  description = "S3 bucket name for configuration (if created)"
  value       = var.create_config_bucket ? aws_s3_bucket.config[0].id : null
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "bedrock_model_arns" {
  description = "ARNs of available Bedrock models"
  value = {
    sonnet = "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0"
    haiku  = "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0"
  }
}
