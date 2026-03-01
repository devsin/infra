# Policy Guardrails Strategy

This document covers **organizational guardrails** — preventive controls applied at the hierarchy level to restrict what child entities can do.

| Cloud | Mechanism | Attached to |
|-------|-----------|-------------|
| AWS | Service Control Policies (SCPs) | OUs / Accounts |
| GCP | Organization Policy Constraints | Org / Folders / Projects |

Both achieve the same goal: defining the **maximum permissions boundary** for resources below them.

---

## AWS: Service Control Policies (SCPs)

### 📋 SCP Overview

SCPs define the **maximum permissions** available to accounts in an OU. They don't grant permissions — they restrict what IAM policies can allow.

### 🎯 SCP Philosophy

1. **Start conservative** — Begin with essential SCPs only
2. **Don't brick yourself** — Always maintain an escape hatch
3. **Layer gradually** — Add stricter controls as you mature
4. **Test in Sandbox first** — Before applying to production

### 📜 SCP Catalog

#### SCP-01: Deny Leaving Organization

**Purpose:** Prevent accounts from being removed from the organization.

**Risk Level:** Low (safe to apply everywhere)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeaveOrganization",
      "Effect": "Deny",
      "Action": [
        "organizations:LeaveOrganization"
      ],
      "Resource": "*"
    }
  ]
}
```

**Attach to:** Platform OU, Workloads OU, Sandbox OU

---

#### SCP-02: Deny Root User Actions

**Purpose:** Prevent use of root user for day-to-day operations.

**Risk Level:** Low-Medium

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRootUser",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:root"
        }
      }
    }
  ]
}
```

**Attach to:** Platform/Security, Platform/SharedServices, Workloads OU, Sandbox OU

**Note:** Consider NOT attaching to the management account initially for break-glass access.

---

#### SCP-03: Block Public S3 Access

**Purpose:** Prevent creation of publicly accessible S3 buckets.

**Risk Level:** Low (high ROI security control)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyS3PublicAccessSettings",
      "Effect": "Deny",
      "Action": [
        "s3:PutBucketPublicAccessBlock"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "s3:PublicAccessBlockConfiguration.BlockPublicAcls": "false"
        }
      }
    },
    {
      "Sid": "DenyPublicBucketACL",
      "Effect": "Deny",
      "Action": [
        "s3:PutBucketAcl",
        "s3:PutObjectAcl"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": [
            "public-read",
            "public-read-write",
            "authenticated-read"
          ]
        }
      }
    }
  ]
}
```

**Attach to:** Platform/SharedServices, Workloads OU, Sandbox OU

---

#### SCP-04: Protect Security Logging

**Purpose:** Prevent tampering with CloudTrail, Config, and log buckets.

**Risk Level:** Medium (needs exceptions for security automation)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyCloudTrailModification",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:DeleteTrail",
        "cloudtrail:StopLogging",
        "cloudtrail:UpdateTrail",
        "cloudtrail:PutEventSelectors"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/{prefix}-security-automation",
            "arn:aws:iam::*:role/OrganizationAccountAccessRole"
          ]
        }
      }
    },
    {
      "Sid": "DenyConfigModification",
      "Effect": "Deny",
      "Action": [
        "config:DeleteConfigurationRecorder",
        "config:DeleteDeliveryChannel",
        "config:StopConfigurationRecorder"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/{prefix}-security-automation",
            "arn:aws:iam::*:role/OrganizationAccountAccessRole"
          ]
        }
      }
    }
  ]
}
```

> ⚠️ In the actual Terraform code, replace `{prefix}` with `var.prefix` via `templatefile()` or string interpolation.

**Attach to:** Workloads OU, Platform/SharedServices

**Note:** Security OU accounts need to manage these services, so apply with exceptions.

---

#### SCP-05: Require MFA for Console Actions (Optional)

**Purpose:** Require MFA for IAM users performing sensitive actions.

**Risk Level:** Medium (can impact operations if not planned)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyActionsWithoutMFA",
      "Effect": "Deny",
      "Action": [
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachUserPolicy",
        "iam:AttachRolePolicy"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
```

**Attach to:** Workloads OU (optional)

**Note:** If using IAM Identity Center (SSO) with Google Workspace, MFA is enforced at the Google Workspace level instead.

---

#### SCP-06: Region Restriction (Phase 2+)

**Purpose:** Prevent resource creation outside allowed regions.

**Risk Level:** HIGH ⚠️ (can break global services if not careful)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRegionsExceptAllowed",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "route53:*",
        "route53domains:*",
        "cloudfront:*",
        "globalaccelerator:*",
        "acm:*",
        "waf:*",
        "wafv2:*",
        "waf-regional:*",
        "budgets:*",
        "support:*",
        "health:*",
        "sts:*",
        "s3:GetBucketLocation",
        "s3:ListAllMyBuckets"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": "REPLACE_WITH_ALLOWED_REGIONS"
        }
      }
    }
  ]
}
```

> In Terraform, use `var.allowed_regions` (e.g. `["eu-west-1", "eu-central-1"]`) to populate the condition.

**Attach to:** Workloads OU, Sandbox OU (NOT Platform initially)

**⚠️ WARNING:** Do NOT apply in Phase 1. Many services have global components that can fail.

---

#### SCP-07: Protect Networking (Phase 3+)

**Purpose:** Prevent "wild" networking that bypasses approved patterns.

**Risk Level:** Medium

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInternetGatewayCreation",
      "Effect": "Deny",
      "Action": [
        "ec2:CreateInternetGateway",
        "ec2:AttachInternetGateway"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/{prefix}-automation",
            "arn:aws:iam::*:role/OrganizationAccountAccessRole"
          ]
        }
      }
    },
    {
      "Sid": "DenyVPCPeering",
      "Effect": "Deny",
      "Action": [
        "ec2:CreateVpcPeeringConnection",
        "ec2:AcceptVpcPeeringConnection"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": [
            "arn:aws:iam::*:role/{prefix}-automation",
            "arn:aws:iam::*:role/OrganizationAccountAccessRole"
          ]
        }
      }
    }
  ]
}
```

**Attach to:** Workloads OU (after networking is established)

### 📊 SCP Attachment Matrix

| SCP | Root | Platform | Platform/Security | Platform/SharedServices | Workloads | Sandbox |
|-----|------|----------|-------------------|------------------------|-----------|---------|
| SCP-01: Deny Leave Org | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| SCP-02: Deny Root User | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| SCP-03: Block Public S3 | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| SCP-04: Protect Logging | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| SCP-05: Require MFA | ❌ | ❌ | ❌ | ❌ | 🔶 | ❌ |
| SCP-06: Region Restrict | ❌ | ❌ | ❌ | ❌ | 🔶 | ✅ |
| SCP-07: Protect Network | ❌ | ❌ | ❌ | ❌ | 🔶 | 🔶 |

**Legend:** ✅ = Apply | ❌ = Don't apply | 🔶 = Optional/Later

### 🚀 Phased SCP Rollout

#### Phase 1 (Day 1) — Essential Only

Apply these immediately:
1. ✅ SCP-01: Deny Leave Org
2. ✅ SCP-03: Block Public S3
3. 🔶 SCP-02: Deny Root User (optional, but recommended)

#### Phase 2 (After Security Services)

Add:
4. ✅ SCP-04: Protect Logging

#### Phase 3+ (After Networking Stable)

Consider adding:
5. 🔶 SCP-06: Region Restriction
6. 🔶 SCP-07: Protect Networking

### ⚠️ SCP Gotchas

#### 1. Avoid Bricking Yourself

Always ensure:
- Management account has unrestricted access
- `OrganizationAccountAccessRole` is excluded from restrictions
- `{prefix}-breakglass` role is excluded where possible

#### 2. Global Services Exception

Many AWS services have global components (IAM, Route53, CloudFront, ACM, etc.).
Region restrictions MUST exclude these.

#### 3. Test Before Production

1. Apply SCP to Sandbox first
2. Test all workflows
3. Then apply to Workloads OU

#### 4. SCP Inheritance

SCPs are inherited down the OU tree:
- Attaching to `Workloads` OU affects ALL brand accounts
- Attaching to `Workloads/{Brand}` affects only that brand's accounts

#### 5. SCP Evaluation

SCPs use "implicit deny" — if any SCP in the chain denies an action, it's denied.
```
Root SCP → Platform SCP → Security SCP → Account IAM Policy
       ↓              ↓              ↓
    (allow)       (allow)        (allow)     → ALLOWED
    (allow)       (deny)         (allow)     → DENIED
```

### 📁 SCP File Organization

```
aws/stacks/1-org/policies/
├── scp-01-deny-leave-org.json
├── scp-02-deny-root-user.json
├── scp-03-block-public-s3.json
├── scp-04-protect-logging.json
├── scp-05-require-mfa.json
├── scp-06-region-restriction.json
└── scp-07-protect-networking.json
```

---

## GCP: Organization Policy Constraints

### 📋 Org Policy Overview

GCP Organization Policies work similarly to SCPs — they constrain what resources/actions are allowed at the **organization, folder, or project** level. Constraints can be boolean (on/off) or list-based (allowed/denied values).

### 🎯 Org Policy Philosophy

Same principles as SCPs:
1. **Start conservative** — Enable essential constraints first
2. **Don't brick yourself** — Bootstrap SA needs broad access initially
3. **Layer gradually** — Add stricter controls per phase
4. **Test in Sandbox first** — Apply to `{fldr}-sandbox` before `{fldr}-workloads`

### 📜 Org Policy Catalog

#### OP-01: Domain Restricted Sharing

**Purpose:** Only allow IAM policy members from your org domain.

**Constraint:** `constraints/iam.allowedPolicyMemberDomains`

```hcl
resource "google_org_policy_policy" "domain_restricted" {
  name   = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = [var.org_customer_id]  # Directory Customer ID
      }
    }
  }
}
```

**Apply to:** Organization root (all folders inherit)

---

#### OP-02: Uniform Bucket-Level Access

**Purpose:** Enforce uniform (IAM-only) access on all GCS buckets — prevents legacy ACLs.

**Constraint:** `constraints/storage.uniformBucketLevelAccess`

```hcl
resource "google_org_policy_policy" "uniform_bucket" {
  name   = "${var.parent}/policies/storage.uniformBucketLevelAccess"
  parent = var.parent  # folder or org

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

**Apply to:** `{fldr}-platform`, `{fldr}-workloads`

---

#### OP-03: Require Shielded VMs

**Purpose:** Ensure all Compute Engine VMs use shielded boot.

**Constraint:** `constraints/compute.requireShieldedVm`

```hcl
resource "google_org_policy_policy" "shielded_vm" {
  name   = "${var.parent}/policies/compute.requireShieldedVm"
  parent = var.parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

**Apply to:** `{fldr}-platform`, `{fldr}-workloads`

---

#### OP-04: Disable Default Service Account Creation

**Purpose:** Prevent auto-creation of default compute/App Engine service accounts (use dedicated SAs instead).

**Constraint:** `constraints/iam.automaticIamGrantsForDefaultServiceAccounts`

```hcl
resource "google_org_policy_policy" "disable_default_sa_grants" {
  name   = "${var.parent}/policies/iam.automaticIamGrantsForDefaultServiceAccounts"
  parent = var.parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

**Apply to:** Organization root

---

#### OP-05: Restrict VPC Peering (Phase 3+)

**Purpose:** Control which projects can peer VPCs.

**Constraint:** `constraints/compute.restrictVpcPeering`

```hcl
resource "google_org_policy_policy" "restrict_peering" {
  name   = "${var.parent}/policies/compute.restrictVpcPeering"
  parent = var.parent

  spec {
    rules {
      values {
        allowed_values = ["under:organizations/${var.org_id}"]
      }
    }
  }
}
```

**Apply to:** `{fldr}-workloads`

---

#### OP-06: Resource Location Restriction (Phase 2+)

**Purpose:** Limit where resources can be created (equivalent to SCP-06).

**Constraint:** `constraints/gcp.resourceLocations`

```hcl
resource "google_org_policy_policy" "resource_locations" {
  name   = "${var.parent}/policies/gcp.resourceLocations"
  parent = var.parent

  spec {
    rules {
      values {
        allowed_values = ["in:europe-west1-locations", "in:europe-west4-locations"]
      }
    }
  }
}
```

**Apply to:** `{fldr}-workloads`, `{fldr}-sandbox`

**⚠️ WARNING:** Apply after Phase 2 — some multi-region resources (GCS, BigQuery) may fail.

---

#### OP-07: Disable Service Account Key Creation (Phase 2+)

**Purpose:** Prevent creation of long-lived SA keys — use WIF or impersonation instead.

**Constraint:** `constraints/iam.disableServiceAccountKeyCreation`

```hcl
resource "google_org_policy_policy" "disable_sa_keys" {
  name   = "${var.parent}/policies/iam.disableServiceAccountKeyCreation"
  parent = var.parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

**Apply to:** `{fldr}-workloads` (NOT bootstrap — WIF setup may need initial key)

### 📊 Org Policy Attachment Matrix

| Org Policy | Org Root | `{fldr}-bootstrap` | `{fldr}-platform` | `{fldr}-workloads` | `{fldr}-sandbox` |
|------------|----------|---------------------|--------------------|--------------------|------------------|
| OP-01: Domain Restriction | ✅ | (inherits) | (inherits) | (inherits) | (inherits) |
| OP-02: Uniform Bucket | ❌ | ❌ | ✅ | ✅ | ✅ |
| OP-03: Shielded VMs | ❌ | ❌ | ✅ | ✅ | ✅ |
| OP-04: Disable Default SA | ✅ | (inherits) | (inherits) | (inherits) | (inherits) |
| OP-05: Restrict Peering | ❌ | ❌ | ❌ | 🔶 | 🔶 |
| OP-06: Location Restrict | ❌ | ❌ | ❌ | 🔶 | 🔶 |
| OP-07: Disable SA Keys | ❌ | ❌ | ❌ | 🔶 | 🔶 |

**Legend:** ✅ = Apply | ❌ = Don't apply | 🔶 = Optional/Later | (inherits) = Inherited from parent

### 🚀 Phased Org Policy Rollout

#### Phase 1 (Day 1) — Essential Only

1. ✅ OP-01: Domain Restricted Sharing
2. ✅ OP-04: Disable Default SA Grants
3. ✅ OP-02: Uniform Bucket-Level Access

#### Phase 2 (After Security Services)

4. ✅ OP-03: Shielded VMs
5. 🔶 OP-07: Disable SA Key Creation

#### Phase 3+ (After Networking Stable)

6. 🔶 OP-05: Restrict VPC Peering
7. 🔶 OP-06: Resource Location Restriction

### ⚠️ Org Policy Gotchas

1. **Inheritance** — Org policies inherit down the folder tree, just like SCPs. Folder-level overrides can relax or tighten.
2. **Bootstrap exception** — `{fldr}-bootstrap` needs relaxed policies since seed SA provisions everything.
3. **Dry run mode** — Use `dryRunSpec` to evaluate impact before enforcing.
4. **Conditionals** — Some constraints support tags/conditions for fine-grained control.

---

## Cross-Cloud Guardrails Comparison

| Concept | AWS SCP | GCP Org Policy |
|---------|---------|----------------|
| Mechanism | JSON policy document | Constraint + rules |
| Effect type | Deny (implicit) | Enforce / Allow/Deny values |
| Inherited? | Yes (down OU tree) | Yes (down folder tree) |
| Override at child? | More restrictive only | Can relax or tighten |
| Attached to | OU or Account | Org, Folder, or Project |
| Management exemption | Management account exempt | Super-admin exempt |
| Test mode | Apply to Sandbox OU | `dryRunSpec` + Sandbox folder |
| Max per node | 5 SCPs per OU | Unlimited constraints |
| Terraform resource | `aws_organizations_policy` | `google_org_policy_policy` |
| Equivalent pairs | SCP-03 (S3 public) | OP-02 (uniform bucket) |
| | SCP-06 (region restrict) | OP-06 (location restrict) |
| | SCP-07 (protect network) | OP-05 (restrict peering) |
