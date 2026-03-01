# ==============================================================================
# Outputs — values needed by all subsequent phases
# ==============================================================================

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "S3 bucket ARN for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "lock_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "lock_table_arn" {
  description = "DynamoDB table ARN for state locking"
  value       = aws_dynamodb_table.terraform_lock.arn
}

output "kms_key_arn" {
  description = "KMS key ARN for state encryption"
  value       = aws_kms_key.terraform_state.arn
}

output "kms_key_id" {
  description = "KMS key ID for state encryption"
  value       = aws_kms_key.terraform_state.key_id
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for GitHub Actions"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "management_account_id" {
  description = "AWS Account ID of the management account"
  value       = local.account_id
}

output "primary_region" {
  description = "Primary AWS region"
  value       = data.aws_region.current.id
}

# ==============================================================================
# Backend config values — copy these into subsequent phases' backend blocks
# ==============================================================================

output "backend_config" {
  description = "Backend configuration for subsequent phases"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    dynamodb_table = aws_dynamodb_table.terraform_lock.name
    region         = data.aws_region.current.id
    encrypt        = true
  }
}
