# Phase 0: Bootstrap

## 🎯 Objective

Set up the foundational infrastructure required for all other phases:
- Terraform state storage (S3 bucket)
- State locking (DynamoDB table)
- Encryption (KMS key)
- CI/CD authentication (OIDC provider for GitHub Actions)

## 📋 What Gets Created

| Resource | Purpose | Account |
|----------|---------|---------|
| S3 Bucket | Terraform state storage | `{prefix}-mgmt` |
| DynamoDB Table | State locking | `{prefix}-mgmt` |
| KMS Key | State encryption | `{prefix}-mgmt` |
| OIDC Provider | GitHub Actions auth | `{prefix}-mgmt` |
| IAM Role | CI/CD assume role | `{prefix}-mgmt` |

## 🏗️ Prerequisites

Before starting Phase 0:

1. **AWS Account**: You need an existing AWS account (this becomes `{prefix}-mgmt`)
2. **AWS CLI**: Version 2.x installed (`brew install awscli`)
3. **Terraform**: Version 1.5+ installed (`brew install terraform`)
4. **Domain**: `{org_domain}` registered (for email aliases via Google Workspace)

## 🔐 AWS Authentication Setup

> **Important:** IAM Identity Center (SSO) isn't available yet — it gets created in Phase 2.
> For Phase 0 bootstrap, use **IAM access keys** from the management account.

### Step 1: Create an IAM User (Console)

1. Log in to the AWS Console with your **root account**
2. Go to **IAM → Users → Create user**
3. Name it something like `terraform-bootstrap`
4. Attach the **AdministratorAccess** policy directly
5. Go to **Security credentials → Create access key**
6. Select **"Command Line Interface (CLI)"** as the use case
7. Copy the **Access Key ID** and **Secret Access Key**

### Step 2: Configure the AWS CLI Profile

```bash
aws configure --profile nd
```

Enter the following when prompted:

```
AWS Access Key ID:     AKIA...         # from step 1
AWS Secret Access Key: ****...         # from step 1
Default region name:   eu-west-1       # your primary region
Default output format: json
```

This writes to `~/.aws/config` and `~/.aws/credentials`.

### Step 3: Set the Profile for Terraform

```bash
export AWS_PROFILE=nd
```

Verify it works:

```bash
aws sts get-caller-identity
```

You should see your account ID and IAM user ARN.

> **Post-Phase 2:** Once IAM Identity Center is deployed, switch to SSO authentication
> (`aws configure sso --profile nd`) and **delete the IAM access keys**.

## 📁 Stack Structure

```
stacks/phase-0-bootstrap/
├── main.tf           # Main resources
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── providers.tf      # Provider configuration
├── versions.tf       # Version constraints
└── terraform.tfvars  # Variable values
```

## 📝 Terraform Configuration

### versions.tf

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### providers.tf

```hcl
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Company     = var.org_name
      ManagedBy   = "terraform"
      Environment = "management"
      Phase       = "0-bootstrap"
    }
  }
}
```

### variables.tf

```hcl
variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "prefix" {
  description = "Short prefix for resource naming (e.g. company abbreviation)"
  type        = string
}

variable "org_name" {
  description = "Organization name (used in tags)"
  type        = string
}

variable "org_domain" {
  description = "Organization domain (used for email aliases)"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name for OIDC trust"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust"
  type        = string
}
```

### main.tf

```hcl
# -----------------------------------------------------------------------------
# S3 Bucket for Terraform State
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.prefix}-terraform-state-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Terraform State"
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

# -----------------------------------------------------------------------------
# DynamoDB Table for State Locking
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${var.prefix}-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock"
  }
}

# -----------------------------------------------------------------------------
# KMS Key for State Encryption
# -----------------------------------------------------------------------------
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "Terraform State Encryption"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${var.prefix}-terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# -----------------------------------------------------------------------------
# OIDC Provider for GitHub Actions
# -----------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "GitHub Actions OIDC"
  }
}

# -----------------------------------------------------------------------------
# IAM Role for GitHub Actions
# -----------------------------------------------------------------------------
resource "aws_iam_role" "github_actions" {
  name = "${var.prefix}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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

  tags = {
    Name = "GitHub Actions Role"
  }
}

# Initial admin permissions for bootstrap
# This will be scoped down after Phase 1
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
```

### outputs.tf

```hcl
output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key for state encryption"
  value       = aws_kms_key.terraform_state.arn
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "management_account_id" {
  description = "AWS Account ID of the management account"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}
```

## 🚀 Deployment Steps

### Step 1: Authenticate & Initialize

```bash
# Set your AWS profile
export AWS_PROFILE=nd

# Verify credentials are working
aws sts get-caller-identity

# Navigate to the stack
cd stacks/phase-0-bootstrap

# Copy the example tfvars and fill in your values
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your prefix, org_name, etc.

# Initialize Terraform (local state initially)
terraform init

# Review the plan
terraform plan

# Apply
terraform apply
```

### Step 2: Migrate State to S3

After the S3 bucket is created, add a backend configuration:

Create `backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "{prefix}-terraform-state-ACCOUNT_ID"  # Replace with actual values
    key            = "bootstrap/terraform.tfstate"
    region         = "eu-west-1"                             # Your primary_region
    encrypt        = true
    dynamodb_table = "{prefix}-terraform-lock"
  }
}
```

Then migrate:
```bash
# Reinitialize with S3 backend
terraform init -migrate-state

# Confirm state migration
terraform plan  # Should show no changes
```

### Step 3: Verify

```bash
# Check state is in S3
aws s3 ls s3://{prefix}-terraform-state-ACCOUNT_ID/bootstrap/

# Verify OIDC provider
aws iam list-open-id-connect-providers
```

## ⚠️ Important Notes

### Chicken-and-Egg Problem

Phase 0 has a bootstrap problem:
1. You need S3 bucket for state
2. But you need Terraform to create S3 bucket
3. Solution: Start with local state, then migrate

### Destroy Considerations

**Can destroy:**
- KMS key (with deletion window)
- DynamoDB table
- OIDC provider
- IAM role

**Cannot easily destroy:**
- S3 bucket with state files (must empty first)
- S3 bucket if other phases' states exist

### Security Notes

1. The initial GitHub Actions role has `AdministratorAccess` — scope this down after Phase 1
2. Enable MFA on the management account root user
3. Consider using AWS Organizations SCPs even on the management account

## 📋 Outputs to Save

After applying, save these values for use in subsequent phases:

```bash
terraform output -json > phase-0-outputs.json
```

Key outputs needed:
- `state_bucket_name` — for backend configs
- `lock_table_name` — for backend configs
- `github_actions_role_arn` — for CI/CD workflows
- `management_account_id` — for organization setup

## ✅ Phase 0 Checklist

- [ ] S3 bucket created with versioning and encryption
- [ ] DynamoDB table created for locking
- [ ] KMS key created and aliased
- [ ] OIDC provider created for GitHub
- [ ] IAM role created for GitHub Actions
- [ ] State migrated from local to S3
- [ ] Outputs saved for subsequent phases
