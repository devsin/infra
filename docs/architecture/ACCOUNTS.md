# Account & Project Strategy

This document covers the **isolation units** for org-scoped cloud providers — AWS accounts and GCP projects. Both follow the same brand-driven pattern.

> All names use `{prefix}-<purpose>` or `{prefix}-{brand}-{env}`.
> Replace `{prefix}` with your project prefix, `{brand}` / `{env}` with values from `brands.yaml`.

---

## AWS Accounts

## 📋 Account List

### Core Platform Accounts (4)

| # | Account Name | Purpose | OU Path | Email |
|---|--------------|---------|---------|-------|
| 1 | `{prefix}-mgmt` | Management/Payer, Organization root | Root | `aws+{prefix}-mgmt@{org_domain}` |
| 2 | `{prefix}-security` | Security tooling, delegated admin | Platform/Security | `aws+{prefix}-security@{org_domain}` |
| 3 | `{prefix}-log` | Central log archive | Platform/Security | `aws+{prefix}-log@{org_domain}` |
| 4 | `{prefix}-shared` | DNS, CI/CD, shared artifacts | Platform/SharedServices | `aws+{prefix}-shared@{org_domain}` |

### Workload Accounts (3 per brand × N brands)

For each brand defined in `var.brands`, the following accounts are created:

| Account Name | Purpose | OU Path | Email |
|--------------|---------|---------|-------|
| `{prefix}-{brand}-dev` | Development environment | `Workloads/{Brand}` | `aws+{prefix}-{brand}-dev@{org_domain}` |
| `{prefix}-{brand}-stage` | Staging environment | `Workloads/{Brand}` | `aws+{prefix}-{brand}-stage@{org_domain}` |
| `{prefix}-{brand}-prod` | Production environment | `Workloads/{Brand}` | `aws+{prefix}-{brand}-prod@{org_domain}` |

#### How It Works

Accounts are generated dynamically from `var.brands`. If you define 2 brands with 3 envs each,
you get 6 workload accounts. The Terraform code uses `for_each` — no manual account definitions.

See the `.tfvars` example in [docs/README.md](../README.md) for how to define your brands.

### Optional Accounts

| # | Account Name | Purpose | OU Path | Email |
|---|--------------|---------|---------|-------|
| 14 | `{prefix}-sandbox` | Experimentation | Sandbox | `aws+{prefix}-sandbox@{org_domain}` |
| 15 | `{prefix}-network` | Centralized networking (if using TGW hub) | Platform/Network | `aws+{prefix}-network@{org_domain}` |

**Total: 4 core + (3 × N brands) workload + optional accounts**

## 🏷️ Naming Convention

### Account Names

```
{prefix}-{brand}-{env}
```

Where:
- `{prefix}` = project/company short prefix (from `var.prefix`)
- `{brand}` = brand key from `var.brands` (e.g. `acme`, `widgets`)
- `{env}` = `dev` | `stage` | `prod`

Platform accounts omit the environment suffix:
- `{prefix}-security`
- `{prefix}-log`
- `{prefix}-shared`
- `{prefix}-mgmt`

## 📧 Email Convention

AWS requires unique emails for each account. Use email aliases with a catch-all domain:

```
aws+{account-name}@{org_domain}
```

### Prerequisites
1. Configure your email provider (Google Workspace) to accept `aws+*@{org_domain}`
2. Ensure all emails route to a monitored inbox
3. Consider using a distribution list for critical accounts

## 🏷️ Tagging & Labeling Strategy

AWS uses **tags**, GCP uses **labels**. The same keys apply to both:

### Required Tags/Labels (All Resources)

| Key | Description | Source |
|-----|-------------|--------|
| `company` | Parent organization | `var.org_name` |
| `brand` | Brand/Product | `var.brand` (from brands list) |
| `environment` | Deployment environment | `var.environment` |
| `managed-by` | How resource is managed | `"terraform"` |
| `owner` | Team/person responsible | `var.owner` |

> **GCP labels** must be lowercase with hyphens. AWS tags can be PascalCase.
> The shared `modules/tagging/` module normalizes keys for each cloud.

### Optional Tags/Labels

| Key | Description | Example Values |
|-----|-------------|----------------|
| `cost-center` | For cost allocation | `platform`, brand name |
| `data-classification` | Data sensitivity | `public`, `internal`, `confidential` |
| `compliance` | Compliance requirements | `gdpr`, `pci`, `none` |

### Terraform Implementation

```hcl
# AWS
locals {
  common_tags = {
    Company     = var.org_name
    Brand       = var.brand
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "${var.prefix}-${var.brand}-${var.environment}-example"
  tags   = local.common_tags
}

# GCP
locals {
  common_labels = {
    company     = var.org_name
    brand       = var.brand
    environment = var.environment
    managed-by  = "terraform"
    owner       = var.owner
  }
}

resource "google_storage_bucket" "example" {
  name   = "${var.project_prefix}-${var.brand}-${var.environment}-example"
  labels = local.common_labels
}
```

## 🔄 Account Lifecycle

### Creation Flow

```
1. Define account in var.accounts (or dynamically from var.brands)
        ↓
2. terraform apply (creates account)
        ↓
3. Account created in Root OU
        ↓
4. Terraform moves to target OU
        ↓
5. SCPs applied via OU membership
        ↓
6. OrganizationAccountAccessRole available
        ↓
7. Bootstrap baseline roles (Phase-1B)
```

### Account Closure (Manual Process)

⚠️ **AWS accounts cannot be instantly deleted via Terraform**

1. Remove all resources from account
2. Disable/remove all services
3. Remove from Organization (optional)
4. Initiate account closure via AWS Console
5. Wait 90-day closure period
6. Remove from Terraform state

## 🚀 Lean Start Approach

If you want to start with fewer accounts:

### Minimal Viable Start

1. `{prefix}-mgmt`
2. `{prefix}-security`
3. `{prefix}-log`
4. `{prefix}-shared`
5. `{prefix}-<your-first-brand>-dev`
6. `{prefix}-<your-first-brand>-prod`

### Add Later
- Stage environments when needed
- Additional brand accounts as those products launch
- Sandbox for experimentation

## 📊 AWS Account Matrix

| Account | Has EKS | Has VPC | Primary Region | DR Region |
|---------|---------|---------|----------------|-----------|
| `{prefix}-mgmt` | ❌ | ❌ | `var.primary_region` | ❌ |
| `{prefix}-security` | ❌ | ❌ | `var.primary_region` | ❌ |
| `{prefix}-log` | ❌ | ❌ | `var.primary_region` | `var.dr_region` |
| `{prefix}-shared` | ❌ | ✅ | `var.primary_region` | ❌ |
| `{prefix}-{brand}-dev` | ✅ | ✅ | `var.primary_region` | ❌ |
| `{prefix}-{brand}-stage` | ✅ | ✅ | `var.primary_region` | ❌ |
| `{prefix}-{brand}-prod` | ✅ | ✅ | `var.primary_region` | `var.dr_region` |

---

## GCP Projects

> GCP uses **projects** as isolation units (equivalent to AWS accounts) and **folders** as hierarchy (equivalent to AWS OUs). See [OU-STRUCTURE.md](./OU-STRUCTURE.md) for folder details.

### Core Platform Projects

| # | Project Name | Purpose | Folder | Created In |
|---|-------------|---------|--------|------------|
| 1 | `{prj}-b-seed` | State bucket, KMS, service accounts | `{fldr}-bootstrap` | Phase 0 |
| 2 | `{prj}-b-cicd-gh` | WIF pool for GitHub Actions CI/CD | `{fldr}-bootstrap` | Phase 0 |
| 3 | `{prj}-security` | SCC, audit sink, org-level security | `{fldr}-platform` | Phase 1 |
| 4 | `{prj}-log` | Central log sink, BigQuery export | `{fldr}-platform` | Phase 1 |
| 5 | `{prj}-shared` | Artifact Registry, shared DNS, KMS | `{fldr}-platform` | Phase 1 |

> `{prj}` = `var.project_prefix`, `{fldr}` = `var.folder_prefix`.

### Workload Projects (per brand × env)

For each brand defined in `brands.yaml`:

| Project Name | Purpose | Folder |
|-------------|---------|--------|
| `{prj}-{brand}-dev` | Development environment | `{fldr}-workloads/{Brand}` |
| `{prj}-{brand}-stage` | Staging environment | `{fldr}-workloads/{Brand}` |
| `{prj}-{brand}-prod` | Production environment | `{fldr}-workloads/{Brand}` |

### Optional Projects

| Project Name | Purpose | Folder |
|-------------|---------|--------|
| `{prj}-sandbox` | Experimentation | `{fldr}-sandbox` |
| `{prj}-network` | Shared VPC host (if needed) | `{fldr}-platform` |

**Total: 5 core + (3 × N brands) workload + optional projects**

### GCP Project Naming

```
{project_prefix}-{brand}-{env}
```

- `{project_prefix}` = short prefix from `var.project_prefix` (e.g. `prj`)
- Platform projects omit brand/env: `{prj}-security`, `{prj}-log`, `{prj}-shared`
- Bootstrap projects use `-b-` infix: `{prj}-b-seed`, `{prj}-b-cicd-gh`

### GCP Project Lifecycle

```
1. Define project in var.brands (dynamically)
        ↓
2. terraform apply (Phase 1 creates projects)
        ↓
3. Project created in target folder
        ↓
4. Org policies inherited via folder
        ↓
5. Service accounts provisioned (Phase 1B)
```

> **Note:** GCP projects can be deleted and re-created more easily than AWS accounts.
> However, project IDs are globally unique and cannot be reused for 30 days after deletion.

### GCP Project Matrix

| Project | Has GKE | Has VPC | Region | DR Region |
|---------|---------|---------|--------|-----------|
| `{prj}-b-seed` | ❌ | ❌ | `var.primary_region` | ❌ |
| `{prj}-b-cicd-gh` | ❌ | ❌ | `var.primary_region` | ❌ |
| `{prj}-security` | ❌ | ❌ | `var.primary_region` | ❌ |
| `{prj}-log` | ❌ | ❌ | `var.primary_region` | `var.dr_region` |
| `{prj}-shared` | ❌ | ✅ | `var.primary_region` | ❌ |
| `{prj}-{brand}-dev` | ✅ | ✅ | `var.primary_region` | ❌ |
| `{prj}-{brand}-stage` | ✅ | ✅ | `var.primary_region` | ❌ |
| `{prj}-{brand}-prod` | ✅ | ✅ | `var.primary_region` | `var.dr_region` |

---

## Cross-Cloud Equivalents

| Concept | AWS | GCP |
|---------|-----|-----|
| Isolation unit | Account | Project |
| Hierarchy | OU (Organizational Unit) | Folder |
| Policy guardrails | SCPs | Org Policies |
| Root identity | Management account | Organization node |
| Naming pattern | `{prefix}-{brand}-{env}` | `{prj}-{brand}-{env}` |
| Email requirement | Unique email per account | Billing account link |
| Deletion | 90-day closure period | Immediate (30-day ID cooldown) |
