# Phase 2: Security (GCP)

## 🎯 Objective

Enable organization-wide security services using the **env service account** (`sa-tf-env`)
from Phase 0:
- Cloud Audit Logs (equivalent to AWS CloudTrail)
- Security Command Center (equivalent to AWS Security Hub + GuardDuty)
- Log sinks to centralized project (equivalent to AWS log archive account)
- Google Workspace as IdP (Cloud Identity integration)

## 🔐 Authentication

```hcl
provider "google" {
  impersonate_service_account = data.terraform_remote_state.bootstrap.outputs.env_sa_email
  region = var.default_region
}

terraform {
  backend "gcs" {
    bucket = "bkt-prj-b-seed-XXXX-tfstate"  # from Phase 0 output
    prefix = "terraform/security"
  }
}
```

## 📋 What Gets Created

| Resource | Purpose | GCP Equivalent of |
|----------|---------|-------------------|
| Org-level log sink | Centralized audit logs | CloudTrail org trail |
| Log bucket | Long-term log storage | S3 log archive bucket |
| SCC enablement | Threat detection | GuardDuty + Security Hub |
| Asset inventory | Resource tracking | AWS Config |
| Cloud Identity | SSO via Google Workspace | IAM Identity Center |

## 📝 Key Resources

```hcl
# Read Phase 0 + Phase 1 outputs
data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "terraform/bootstrap"
  }
}

locals {
  org_id     = data.terraform_remote_state.bootstrap.outputs.common_config.org_id
  log_project = data.terraform_remote_state.org.outputs.log_project_id
}

# Organization-level log sink → centralized log project
resource "google_logging_organization_sink" "central" {
  name             = "${var.prefix}-central-audit"
  org_id           = local.org_id
  destination      = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"
  include_children = true

  filter = "logName:\"cloudaudit.googleapis.com\""
}

# Central audit log bucket
resource "google_storage_bucket" "audit_logs" {
  name     = "${var.prefix}-audit-logs-${var.log_project_id}"
  project  = var.log_project_id
  location = var.primary_region

  retention_policy {
    retention_period = 31536000  # 365 days
  }

  uniform_bucket_level_access = true
}

# Security Command Center (org-level)
resource "google_scc_organization_settings" "main" {
  organization_id        = local.org_id
  enable_asset_discovery = true
}
```

## 🔑 GCP vs AWS Security Comparison

| Feature | AWS | GCP |
|---------|-----|-----|
| Audit logging | CloudTrail | Cloud Audit Logs |
| Threat detection | GuardDuty | Security Command Center |
| Compliance | Security Hub | SCC + Compliance reports |
| Resource inventory | AWS Config | Cloud Asset Inventory |
| SSO/IdP | Identity Center + Google WS SAML | Native Cloud Identity / Google WS |
| Log centralization | S3 in log account | GCS bucket in log project |

> **Note:** Google Workspace is already the native IdP for GCP — no SAML federation needed (unlike AWS).

## ✅ Phase 2 Checklist

- [ ] Organization log sink to centralized project
- [ ] Audit log bucket with retention policy
- [ ] Security Command Center enabled
- [ ] Asset discovery enabled
- [ ] Cloud Identity groups for RBAC
- [ ] VPC Service Controls perimeter (optional)
