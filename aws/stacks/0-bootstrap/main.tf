# ==============================================================================
# Phase 0: Bootstrap
#
# Creates the foundational infrastructure for all subsequent phases:
#   - S3 bucket for Terraform state
#   - DynamoDB table for state locking
#   - KMS key for state encryption
#   - OIDC provider for GitHub Actions CI/CD
#   - IAM role for GitHub Actions
#
# Deployment:
#   1. terraform init                    (local state first)
#   2. terraform apply
#   3. Uncomment backend.tf
#   4. terraform init -migrate-state     (migrate to S3)
# ==============================================================================

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "${var.prefix}-terraform-state-${local.account_id}"
}

# ------------------------------------------------------------------------------
# S3 Bucket — Terraform State
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.bucket_name
  force_destroy = var.state_bucket_force_destroy

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.prefix}-terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ------------------------------------------------------------------------------
# DynamoDB Table — State Locking
# ------------------------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${var.prefix}-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.prefix}-terraform-lock"
  }
}

# ------------------------------------------------------------------------------
# KMS Key — State Encryption
# ------------------------------------------------------------------------------

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3ServiceEncryption"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-terraform-state-kms"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${var.prefix}-terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# ------------------------------------------------------------------------------
# OIDC Provider — GitHub Actions
# ------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint — AWS validates the TLS certificate chain automatically
  # for token.actions.githubusercontent.com, this value is a known-good fallback.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "${var.prefix}-github-oidc"
  }
}

# ------------------------------------------------------------------------------
# IAM Role — GitHub Actions
# ------------------------------------------------------------------------------

resource "aws_iam_role" "github_actions" {
  name        = "${var.prefix}-github-actions"
  description = "Role assumed by GitHub Actions via OIDC for CI/CD"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGitHubOIDC"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  max_session_duration = 3600

  tags = {
    Name = "${var.prefix}-github-actions"
  }
}

# Bootstrap: AdministratorAccess — will be scoped down after Phase 1 when
# per-account automation roles ({prefix}-automation) are in place.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
