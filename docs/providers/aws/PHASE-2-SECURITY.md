# Phase 2: Security Baseline

## 🎯 Objective

Enable organization-wide security services and configure identity:
- CloudTrail (Organization trail)
- AWS Config (with aggregator)
- GuardDuty (delegated admin)
- Security Hub (delegated admin)
- Central log archive bucket
- **IAM Identity Center (SSO) with Google Workspace as IdP**

## 📋 What Gets Created

| Resource | Account | Purpose |
|----------|---------|---------|
| CloudTrail Org Trail | `{prefix}-security` (delegated) | Audit logging |
| S3 Bucket (logs) | `{prefix}-log` | Central log storage |
| AWS Config | All accounts | Compliance recording |
| Config Aggregator | `{prefix}-security` | Central view |
| GuardDuty | All accounts | Threat detection |
| Security Hub | All accounts | Security posture |
| IAM Identity Center | `{prefix}-mgmt` | SSO via Google Workspace |

## 🏗️ Prerequisites

- Phase 1 completed (all accounts and OUs exist)
- Phase 1B completed (baseline IAM roles exist)
- Account IDs from Phase 1 outputs
- **Google Workspace admin access** (for SAML/SSO configuration)

## 📁 Stack Structure

```
stacks/phase-2-security/
├── main.tf              # Main orchestration
├── cloudtrail.tf        # Organization trail
├── config.tf            # AWS Config setup
├── guardduty.tf         # GuardDuty setup
├── security-hub.tf      # Security Hub setup
├── log-bucket.tf        # Central log bucket
├── delegated-admin.tf   # Delegated admin setup
├── identity-center.tf   # IAM Identity Center + Google Workspace
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── backend.tf
└── terraform.tfvars
```

## 📝 Key Resources

### Delegated Administrator Setup

```hcl
resource "aws_organizations_delegated_administrator" "security_cloudtrail" {
  account_id        = var.security_account_id
  service_principal = "cloudtrail.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "security_guardduty" {
  account_id        = var.security_account_id
  service_principal = "guardduty.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "security_securityhub" {
  account_id        = var.security_account_id
  service_principal = "securityhub.amazonaws.com"
}

resource "aws_organizations_delegated_administrator" "security_config" {
  account_id        = var.security_account_id
  service_principal = "config.amazonaws.com"
}
```

### CloudTrail Organization Trail

```hcl
resource "aws_cloudtrail" "org_trail" {
  name                          = "${var.prefix}-org-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail        = true
  is_organization_trail        = true
  enable_log_file_validation   = true

  kms_key_id = aws_kms_key.cloudtrail.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
```

### Central Log Bucket (in `{prefix}-log`)

```hcl
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.prefix}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceOrgID" = var.organization_id
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"   = "bucket-owner-full-control"
            "aws:SourceOrgID" = var.organization_id
          }
        }
      }
    ]
  })
}
```

## 🔐 IAM Identity Center (SSO) with Google Workspace

### Overview

Human users authenticate via **Google Workspace** → **AWS IAM Identity Center** (formerly AWS SSO). This provides:
- Single sign-on to all AWS accounts via Google Workspace credentials
- MFA enforced at the Google Workspace level
- Group-based access mapping (Google Groups → AWS Permission Sets)
- No IAM users needed in member accounts

### Architecture

```
┌─────────────────┐      SAML 2.0       ┌─────────────────────────┐
│                 │◄────────────────────►│                         │
│ Google Workspace│                      │  AWS IAM Identity Center│
│ (@{org_domain}) │   ┌──────────────┐   │  (in {prefix}-mgmt)     │
│                 │──►│ Google Groups│──►│                         │
│  • Users        │   │              │   │  Permission Sets:       │
│  • MFA          │   │ • Admins     │   │  • AdministratorAccess  │
│  • Groups       │   │ • Developers │   │  • ReadOnlyAccess       │
│                 │   │ • Security   │   │  • DeveloperAccess      │
└─────────────────┘   └──────────────┘   └─────────┬───────────────┘
                                                     │
                                           Account Assignments
                                                     │
                      ┌──────────────────────────────┼──────────────┐
                      │                              │              │
               ┌──────▼──────┐  ┌────────────────┐  │  ┌───────────▼──┐
               │{prefix}-mgmt│  │{prefix}-security│  │  │{prefix}-     │
               │  (Admins)   │  │  (Security)    │  │  │{brand}-prod  │
               └─────────────┘  └────────────────┘  │  └──────────────┘
                                                     │
                                              ... all accounts
```

### Setup Steps (Manual + Terraform)

#### Step 1: Enable IAM Identity Center (Console)

1. Go to **IAM Identity Center** in `{prefix}-mgmt` account
2. Choose **Enable with AWS Organizations**
3. Select your preferred region (should match `var.primary_region`)

#### Step 2: Configure Google Workspace as External IdP

1. In **IAM Identity Center → Settings → Identity source**, click **Actions → Change identity source**
2. Select **External identity provider**
3. Download the **AWS SSO SAML metadata** file
4. In **Google Admin Console** (`admin.google.com`):
   - Go to **Apps → Web and mobile apps → Add app → Search for apps → Amazon Web Services**
   - Or: **Add app → Add custom SAML app**
   - Upload the AWS metadata / enter SSO URL and certificate
   - Map Google attributes to AWS:
     - `Primary email` → `https://aws.amazon.com/SAML/Attributes/RoleSessionName`
     - `First name` → `https://aws.amazon.com/SAML/Attributes/PrincipalTag:FirstName`
     - `Last name` → `https://aws.amazon.com/SAML/Attributes/PrincipalTag:LastName`
5. Copy Google IdP **metadata URL** (or download XML)
6. Back in AWS IAM Identity Center, upload the **Google IdP metadata**
7. Enable **Automatic provisioning (SCIM)** for user/group sync:
   - Copy the SCIM endpoint URL and access token from AWS
   - In Google Admin, configure auto-provisioning with these values

#### Step 3: Terraform — Permission Sets and Account Assignments

```hcl
# identity-center.tf

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

# --- Permission Sets ---

resource "aws_ssoadmin_permission_set" "admin" {
  name             = "AdministratorAccess"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H"
  description      = "Full admin access"
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "ReadOnlyAccess"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  description      = "Read-only access for auditing"
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_ssoadmin_permission_set" "developer" {
  name             = "DeveloperAccess"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  description      = "Developer access (PowerUser + EKS)"
}

resource "aws_ssoadmin_managed_policy_attachment" "developer" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# --- Account Assignments (via Google Groups synced through SCIM) ---
# Groups are synced from Google Workspace via SCIM provisioning.
# Use data source to look up the synced group:

data "aws_identitystore_group" "admins" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "AWS-Admins"  # Google Group name
    }
  }
}

# Assign Admin group to management account
resource "aws_ssoadmin_account_assignment" "admins_mgmt" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn

  principal_id   = data.aws_identitystore_group.admins.group_id
  principal_type = "GROUP"

  target_id   = var.management_account_id
  target_type = "AWS_ACCOUNT"
}

# Assign to all workload accounts dynamically
resource "aws_ssoadmin_account_assignment" "admins_workloads" {
  for_each = var.account_ids

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn

  principal_id   = data.aws_identitystore_group.admins.group_id
  principal_type = "GROUP"

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}
```

### Google Workspace Groups → AWS Mapping (Recommended)

| Google Group | AWS Permission Set | Assigned Accounts |
|-------------|-------------------|-------------------|
| `AWS-Admins` | AdministratorAccess | All accounts |
| `AWS-Security` | SecurityAudit + custom | `{prefix}-security`, `{prefix}-log` |
| `AWS-Developers-{brand}` | DeveloperAccess | `{prefix}-{brand}-dev`, `{prefix}-{brand}-stage` |
| `AWS-ReadOnly` | ReadOnlyAccess | All accounts |

### SSO Login Flow

```
1. User goes to: https://{sso-start-url}.awsapps.com/start
2. Redirected to Google Workspace sign-in
3. Authenticates with Google (MFA enforced by Google)
4. Returns to AWS SSO portal
5. Sees list of assigned accounts + permission sets
6. Clicks to open Console or copy CLI credentials
```

## 💰 Cost Considerations

Security services can add significant baseline cost:

| Service | Cost Driver | Estimate |
|---------|-------------|----------|
| CloudTrail | Storage + data events | ~$2-10/account/month |
| AWS Config | Rules + recorded resources | ~$5-50/account/month |
| GuardDuty | Analyzed data volume | ~$5-30/account/month |
| Security Hub | Findings + checks | ~$1-10/account/month |
| IAM Identity Center | Free | $0 |

**Tip:** Start with management events only for CloudTrail; add data events later.

## 🚀 Deployment Steps

```bash
cd stacks/phase-2-security

terraform init
terraform plan

# Apply in stages:
# 1. Delegated admin setup
terraform apply -target=aws_organizations_delegated_administrator.security_cloudtrail
# ... repeat for other delegated admins

# 2. Log bucket
terraform apply -target=module.log_bucket

# 3. CloudTrail
terraform apply -target=module.cloudtrail

# 4. Config, GuardDuty, Security Hub
terraform apply

# 5. Identity Center (after manual IdP setup)
terraform apply -target=module.identity_center
```

## ⚠️ Important Notes

### Google Workspace Integration

- SCIM provisioning syncs users & groups from Google Workspace to IAM Identity Center
- If a user is removed from Google Workspace, their AWS SSO access is revoked
- MFA is enforced by Google Workspace — no need to configure MFA in AWS separately
- Google Workspace Super Admin does NOT automatically get AWS access; explicit group membership is required

### Delegated Admin Limitations

- Only one delegated admin per service
- Some services require enablement in management account first
- Removal of delegated admin can orphan resources

### Multi-Region Considerations

- CloudTrail: Single multi-region trail is sufficient
- GuardDuty: Must be enabled per region
- Security Hub: Must be enabled per region
- Config: Recorder needed per region
- IAM Identity Center: Single region only (your `primary_region`)

## ✅ Phase 2 Checklist

- [ ] `{prefix}-security` designated as delegated admin for all services
- [ ] Central log bucket in `{prefix}-log` with correct policies
- [ ] CloudTrail org trail enabled and logging
- [ ] AWS Config enabled in all accounts
- [ ] Config aggregator in `{prefix}-security`
- [ ] GuardDuty enabled org-wide
- [ ] Security Hub enabled with standards (CIS, AWS Best Practices)
- [ ] KMS keys for encryption where needed
- [ ] IAM Identity Center enabled with Google Workspace as IdP
- [ ] SCIM provisioning active (users/groups syncing)
- [ ] Permission sets created (Admin, Developer, ReadOnly)
- [ ] Account assignments configured
- [ ] SSO login tested and working
- [ ] SCP-04 (Protect Logging) can now be attached
