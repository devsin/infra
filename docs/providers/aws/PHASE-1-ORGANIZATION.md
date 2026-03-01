# Phase 1: Organization

## 🎯 Objective

Create the AWS Organization structure with:
- Organization with all features enabled
- OU (Organizational Unit) hierarchy — dynamic from `var.brands`
- Member accounts placed in correct OUs
- Base SCPs (Service Control Policies)

## 📋 What Gets Created

| Resource | Count | Notes |
|----------|-------|-------|
| Organization | 1 | Feature set: ALL |
| OUs | 5 + N brands | Platform, Security, SharedServices, Workloads, Sandbox + 1 per brand |
| Accounts | 4 core + (3 × N brands) | Core platform + workload accounts |
| SCPs | 3-4 | Base guardrails |

## 🏗️ Prerequisites

- Phase 0 completed
- Management account has Organizations enabled
- Admin access to management account

## 📁 Stack Structure

```
stacks/phase-1-org/
├── main.tf           # Organization and OU creation
├── accounts.tf       # Account definitions
├── scps.tf           # SCP creation and attachment
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── providers.tf      # Provider configuration
├── versions.tf       # Version constraints
├── backend.tf        # S3 backend
└── terraform.tfvars  # Variable values
```

## 📝 Terraform Configuration

### backend.tf

```hcl
terraform {
  backend "s3" {
    bucket         = "{prefix}-terraform-state-ACCOUNT_ID"  # From Phase 0
    key            = "org/terraform.tfstate"
    region         = "eu-west-1"                             # var.primary_region
    encrypt        = true
    dynamodb_table = "{prefix}-terraform-lock"
  }
}
```

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
  alias  = "management"

  default_tags {
    tags = {
      Company   = var.org_name
      ManagedBy = "terraform"
      Phase     = "1-org"
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
  description = "Short prefix for resource naming"
  type        = string
}

variable "org_name" {
  description = "Organization name"
  type        = string
}

variable "org_domain" {
  description = "Organization domain for email aliases"
  type        = string
}

variable "brands" {
  description = "List of brand/product definitions"
  type = list(object({
    name   = string
    domain = string
    envs   = list(string)
  }))
}

variable "enable_sandbox" {
  description = "Whether to create sandbox account"
  type        = bool
  default     = false
}
```

### main.tf

```hcl
# -----------------------------------------------------------------------------
# Derived locals — build OUs and accounts dynamically from var.brands
# -----------------------------------------------------------------------------
locals {
  # Static OUs
  static_ous = [
    { name = "Platform",       path = "Platform",                parent_path = "" },
    { name = "Workloads",      path = "Workloads",               parent_path = "" },
    { name = "Sandbox",        path = "Sandbox",                 parent_path = "" },
    { name = "Security",       path = "Platform/Security",       parent_path = "Platform" },
    { name = "SharedServices", path = "Platform/SharedServices", parent_path = "Platform" },
  ]

  # Dynamic brand OUs
  brand_ous = [
    for brand in var.brands : {
      name        = title(brand.name)
      path        = "Workloads/${title(brand.name)}"
      parent_path = "Workloads"
    }
  ]

  ou_structure = concat(local.static_ous, local.brand_ous)

  # Core platform accounts (always created)
  core_accounts = [
    {
      name        = "${var.prefix}-security"
      email       = "aws+${var.prefix}-security@${var.org_domain}"
      ou_path     = "Platform/Security"
      environment = "platform"
      brand       = "platform"
    },
    {
      name        = "${var.prefix}-log"
      email       = "aws+${var.prefix}-log@${var.org_domain}"
      ou_path     = "Platform/Security"
      environment = "platform"
      brand       = "platform"
    },
    {
      name        = "${var.prefix}-shared"
      email       = "aws+${var.prefix}-shared@${var.org_domain}"
      ou_path     = "Platform/SharedServices"
      environment = "platform"
      brand       = "platform"
    },
  ]

  # Workload accounts (dynamic: brand × env)
  workload_accounts = flatten([
    for brand in var.brands : [
      for env in brand.envs : {
        name        = "${var.prefix}-${brand.name}-${env}"
        email       = "aws+${var.prefix}-${brand.name}-${env}@${var.org_domain}"
        ou_path     = "Workloads/${title(brand.name)}"
        environment = env
        brand       = brand.name
      }
    ]
  ])

  all_accounts = concat(local.core_accounts, local.workload_accounts)
}

# -----------------------------------------------------------------------------
# AWS Organization
# -----------------------------------------------------------------------------
resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]

  feature_set = "ALL"
}

# -----------------------------------------------------------------------------
# Organizational Units
# -----------------------------------------------------------------------------
locals {
  level1_ous = [for ou in local.ou_structure : ou if ou.parent_path == ""]
  level2_ous = [for ou in local.ou_structure : ou if ou.parent_path != ""]
}

# Level 1 OUs
resource "aws_organizations_organizational_unit" "level1" {
  for_each = { for ou in local.level1_ous : ou.path => ou }

  name      = each.value.name
  parent_id = aws_organizations_organization.org.roots[0].id

  tags = {
    Name = each.value.name
    Path = each.value.path
  }
}

# Level 2 OUs
resource "aws_organizations_organizational_unit" "level2" {
  for_each = { for ou in local.level2_ous : ou.path => ou }

  name      = each.value.name
  parent_id = aws_organizations_organizational_unit.level1[each.value.parent_path].id

  tags = {
    Name = each.value.name
    Path = each.value.path
  }

  depends_on = [aws_organizations_organizational_unit.level1]
}

# Combined OU lookup
locals {
  all_ous = merge(
    { for k, v in aws_organizations_organizational_unit.level1 : k => v },
    { for k, v in aws_organizations_organizational_unit.level2 : k => v }
  )
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
```

### accounts.tf

```hcl
# -----------------------------------------------------------------------------
# Member Accounts (dynamic)
# -----------------------------------------------------------------------------
resource "aws_organizations_account" "accounts" {
  for_each = { for acc in local.all_accounts : acc.name => acc }

  name      = each.value.name
  email     = each.value.email
  parent_id = local.all_ous[each.value.ou_path].id

  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  tags = {
    Name        = each.value.name
    Environment = each.value.environment
    Brand       = each.value.brand
  }

  lifecycle {
    ignore_changes = [email]
  }

  depends_on = [
    aws_organizations_organizational_unit.level1,
    aws_organizations_organizational_unit.level2
  ]
}

# Optional: Sandbox account
resource "aws_organizations_account" "sandbox" {
  count = var.enable_sandbox ? 1 : 0

  name      = "${var.prefix}-sandbox"
  email     = "aws+${var.prefix}-sandbox@${var.org_domain}"
  parent_id = aws_organizations_organizational_unit.level1["Sandbox"].id

  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = false

  tags = {
    Name        = "${var.prefix}-sandbox"
    Environment = "sandbox"
    Brand       = "platform"
  }
}

# -----------------------------------------------------------------------------
# Account ID Lookup
# -----------------------------------------------------------------------------
locals {
  account_ids = {
    for name, account in aws_organizations_account.accounts : name => account.id
  }
}
```

### scps.tf

```hcl
# -----------------------------------------------------------------------------
# SCP: Deny Leaving Organization
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_leave_org" {
  name        = "DenyLeaveOrganization"
  description = "Prevents accounts from leaving the organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLeaveOrganization"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# SCP: Deny Root User Actions
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_root_user" {
  name        = "DenyRootUserActions"
  description = "Prevents use of root user credentials"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRootUser"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# SCP: Block Public S3
# -----------------------------------------------------------------------------
resource "aws_organizations_policy" "block_public_s3" {
  name        = "BlockPublicS3"
  description = "Prevents public S3 bucket access"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicBucketACL"
        Effect = "Deny"
        Action = [
          "s3:PutBucketAcl",
          "s3:PutObjectAcl"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = [
              "public-read",
              "public-read-write",
              "authenticated-read"
            ]
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# SCP Attachments
# -----------------------------------------------------------------------------

# Attach DenyLeaveOrg to all non-root OUs
resource "aws_organizations_policy_attachment" "deny_leave_platform" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organizational_unit.level1["Platform"].id
}

resource "aws_organizations_policy_attachment" "deny_leave_workloads" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organizational_unit.level1["Workloads"].id
}

resource "aws_organizations_policy_attachment" "deny_leave_sandbox" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organizational_unit.level1["Sandbox"].id
}

# Attach DenyRootUser to Workloads and SharedServices
resource "aws_organizations_policy_attachment" "deny_root_workloads" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.level1["Workloads"].id
}

resource "aws_organizations_policy_attachment" "deny_root_shared" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.level2["Platform/SharedServices"].id
}

resource "aws_organizations_policy_attachment" "deny_root_sandbox" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.level1["Sandbox"].id
}

# Attach BlockPublicS3 to Workloads, SharedServices, and Sandbox
resource "aws_organizations_policy_attachment" "block_s3_workloads" {
  policy_id = aws_organizations_policy.block_public_s3.id
  target_id = aws_organizations_organizational_unit.level1["Workloads"].id
}

resource "aws_organizations_policy_attachment" "block_s3_shared" {
  policy_id = aws_organizations_policy.block_public_s3.id
  target_id = aws_organizations_organizational_unit.level2["Platform/SharedServices"].id
}

resource "aws_organizations_policy_attachment" "block_s3_sandbox" {
  policy_id = aws_organizations_policy.block_public_s3.id
  target_id = aws_organizations_organizational_unit.level1["Sandbox"].id
}
```

### outputs.tf

```hcl
output "organization_id" {
  description = "The Organization ID"
  value       = aws_organizations_organization.org.id
}

output "organization_arn" {
  description = "The Organization ARN"
  value       = aws_organizations_organization.org.arn
}

output "root_id" {
  description = "The Organization root ID"
  value       = aws_organizations_organization.org.roots[0].id
}

output "management_account_id" {
  description = "The management account ID"
  value       = aws_organizations_organization.org.master_account_id
}

output "ou_ids" {
  description = "Map of OU paths to IDs"
  value = {
    for path, ou in local.all_ous : path => ou.id
  }
}

output "account_ids" {
  description = "Map of account names to account IDs"
  value       = local.account_ids
}

output "accounts" {
  description = "Full account details"
  value = {
    for name, account in aws_organizations_account.accounts : name => {
      id    = account.id
      arn   = account.arn
      email = account.email
    }
  }
  sensitive = true
}

output "scp_ids" {
  description = "Map of SCP names to IDs"
  value = {
    deny_leave_org  = aws_organizations_policy.deny_leave_org.id
    deny_root_user  = aws_organizations_policy.deny_root_user.id
    block_public_s3 = aws_organizations_policy.block_public_s3.id
  }
}
```

## 🚀 Deployment Steps

### Step 1: Initialize and Plan

```bash
cd stacks/phase-1-org

# Update backend.tf with your account ID from Phase 0

terraform init
terraform plan -out=plan.tfplan
```

### Step 2: Apply in Stages (Recommended)

Due to account creation quotas and dependencies, apply in stages:

```bash
# Stage 1: Create organization and OUs only
terraform apply -target=aws_organizations_organization.org
terraform apply -target=aws_organizations_organizational_unit.level1
terraform apply -target=aws_organizations_organizational_unit.level2

# Stage 2: Create accounts (one at a time if hitting limits)
terraform apply -target=aws_organizations_account.accounts

# Stage 3: Create and attach SCPs
terraform apply
```

### Step 3: Verify

```bash
# List OUs
aws organizations list-roots
aws organizations list-organizational-units-for-parent --parent-id <root-id>

# List accounts
aws organizations list-accounts

# Verify SCP attachments
aws organizations list-policies --filter SERVICE_CONTROL_POLICY
```

## ⚠️ Important Notes

### Account Creation Limits

AWS has limits on account creation:
- Default: ~4 accounts per hour
- You can request a limit increase via Support

If you hit limits, wait and re-run `terraform apply`.

### Account Closure Warning

⚠️ **AWS accounts CANNOT be instantly deleted**

To remove an account:
1. Remove all resources from the account
2. Initiate closure via AWS Console
3. Wait 90-day closure period
4. Then remove from Terraform state

### Email Requirements

- Each account needs a unique email
- Ensure emails are actually receivable (for password resets)
- Use email aliases: `aws+{prefix}-{account}@{org_domain}`
- Google Workspace catch-all or alias routing recommended

### OrganizationAccountAccessRole

AWS automatically creates this role in each new account:
- Allows management account to assume into member accounts
- Has `AdministratorAccess`
- Use this for initial access, then create your own roles

## 🔄 Post-Deployment: Create Baseline Roles

After accounts are created, run Phase 1B to create baseline roles in each account.

See: [Phase 1B: IAM Baseline](./PHASE-1B-IAM-BASELINE.md)

## 🗑️ Destroy Considerations

### What Can Be Destroyed
- ✅ SCPs (if detached first)
- ✅ SCP attachments
- ✅ Empty OUs
- ✅ Organization settings

### What Cannot Be Easily Destroyed
- ❌ Accounts (can only close, not delete)
- ❌ OUs with accounts in them
- ❌ Organization while accounts exist

## ✅ Phase 1 Checklist

- [ ] Organization created with `ALL` features
- [ ] Service access principals enabled
- [ ] All Level 1 OUs created (Platform, Workloads, Sandbox)
- [ ] All Level 2 OUs created (Security, SharedServices, per-brand)
- [ ] All accounts created with correct emails
- [ ] All accounts in correct OUs
- [ ] DenyLeaveOrg SCP attached
- [ ] DenyRootUser SCP attached (where appropriate)
- [ ] BlockPublicS3 SCP attached
- [ ] Outputs saved for Phase 1B / Phase 2

## 📋 Outputs to Save

```bash
terraform output -json > phase-1-outputs.json
```

Key outputs needed for subsequent phases:
- `organization_id`
- `root_id`
- `account_ids`
- `ou_ids`
