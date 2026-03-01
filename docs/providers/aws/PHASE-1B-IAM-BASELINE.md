# Phase 1B: IAM Baseline

## 🎯 Objective

Create standardized IAM roles in each member account:
- `{prefix}-automation` — For CI/CD pipelines (GitHub Actions OIDC)
- `{prefix}-breakglass` — For emergency human access (MFA required)

## 📋 Why a Separate Phase?

Creating IAM roles inside newly created accounts requires:
1. Accounts must exist first
2. Must assume into each account using `OrganizationAccountAccessRole`
3. Keeping this separate allows re-running without touching org structure

## 🏗️ Prerequisites

- Phase 1 completed (accounts exist)
- Access to management account with ability to assume into member accounts

## 📁 Stack Structure

```
stacks/phase-1b-iam-baseline/
├── main.tf           # Role creation logic
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── providers.tf      # Dynamic providers for each account
├── versions.tf       # Version constraints
├── backend.tf        # S3 backend
└── terraform.tfvars  # Variable values (account IDs from Phase 1)
```

## 📝 Terraform Configuration

### variables.tf

```hcl
variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "prefix" {
  description = "Short prefix for resource naming"
  type        = string
}

variable "management_account_id" {
  description = "Management account ID (from Phase 1)"
  type        = string
}

variable "account_ids" {
  description = "Map of account names to IDs (from Phase 1 output)"
  type        = map(string)
}

variable "github_org" {
  description = "GitHub organization for OIDC trust"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository for OIDC trust"
  type        = string
}
```

### providers.tf

```hcl
# Management account provider
provider "aws" {
  region = var.primary_region
  alias  = "management"
}

# Dynamic providers for each member account
# Using assume_role with OrganizationAccountAccessRole
#
# Generate one provider block per account in var.account_ids:

provider "aws" {
  region = var.primary_region
  alias  = "account"  # Use a for_each-friendly pattern

  assume_role {
    role_arn = "arn:aws:iam::${each.value}:role/OrganizationAccountAccessRole"
  }
}
```

> **Note:** Terraform does not support `for_each` on provider blocks. In practice you must either:
> 1. Generate one provider alias per account (via code generation / templatefile), or
> 2. Use a single module call with `for_each` and pass the account ID, then have the module use `assume_role` inside its own provider.

### main.tf

```hcl
# -----------------------------------------------------------------------------
# Module: IAM Baseline Roles
# Called once per account via for_each
# -----------------------------------------------------------------------------
module "iam_baseline" {
  source   = "../../modules/iam-baseline"
  for_each = var.account_ids

  providers = {
    aws = aws.account  # See providers.tf note above
  }

  account_name          = each.key
  prefix                = var.prefix
  management_account_id = var.management_account_id
  github_org            = var.github_org
  github_repo           = var.github_repo
  environment           = lookup(local.account_environments, each.key, "platform")
}

locals {
  # Derive environment from account name convention: {prefix}-{brand}-{env}
  account_environments = {
    for name, id in var.account_ids :
    name => try(
      regex("-(dev|stage|prod)$", name)[0],
      "platform"
    )
  }
}
```

## 📦 IAM Baseline Module

### modules/iam-baseline/variables.tf

```hcl
variable "account_name" {
  description = "Name of the account"
  type        = string
}

variable "prefix" {
  description = "Short prefix for role naming"
  type        = string
}

variable "management_account_id" {
  description = "Management account ID for trust"
  type        = string
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository"
  type        = string
}

variable "environment" {
  description = "Environment (dev/stage/prod/platform)"
  type        = string
}
```

### modules/iam-baseline/main.tf

```hcl
# -----------------------------------------------------------------------------
# OIDC Provider (if not exists)
# -----------------------------------------------------------------------------
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = data.aws_iam_openid_connect_provider.github.arn != null ? 0 : 1

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  oidc_provider_arn = try(
    data.aws_iam_openid_connect_provider.github.arn,
    aws_iam_openid_connect_provider.github[0].arn
  )
}

# -----------------------------------------------------------------------------
# {prefix}-automation Role (for CI/CD)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "automation" {
  name = "${var.prefix}-automation"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Trust GitHub Actions OIDC
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
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
      },
      # Trust management account (for cross-account assume)
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.management_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.prefix}-automation"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-automation"
    Purpose     = "CI/CD automation"
    Environment = var.environment
  }
}

# Permissions for automation role (start with admin, scope down later)
resource "aws_iam_role_policy_attachment" "automation_admin" {
  role       = aws_iam_role.automation.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# {prefix}-breakglass Role (for emergency access)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "breakglass" {
  name = "${var.prefix}-breakglass"

  # Longer session for troubleshooting
  max_session_duration = 43200  # 12 hours

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.management_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-breakglass"
    Purpose     = "Emergency human access"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "breakglass_admin" {
  role       = aws_iam_role.breakglass.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
```

### modules/iam-baseline/outputs.tf

```hcl
output "automation_role_arn" {
  description = "ARN of the automation role"
  value       = aws_iam_role.automation.arn
}

output "breakglass_role_arn" {
  description = "ARN of the breakglass role"
  value       = aws_iam_role.breakglass.arn
}
```

## 🚀 Deployment Steps

```bash
cd stacks/phase-1b-iam-baseline

# Copy account IDs from Phase 1 output
# Update terraform.tfvars with account_ids map

terraform init
terraform plan
terraform apply
```

## ✅ Phase 1B Checklist

- [ ] OIDC provider created in each account
- [ ] `{prefix}-automation` role in each account
- [ ] `{prefix}-breakglass` role in each account
- [ ] Roles have appropriate trust policies
- [ ] Roles have initial permissions (to be scoped down)
