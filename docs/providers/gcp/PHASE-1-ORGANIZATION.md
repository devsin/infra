# Phase 1: Organization (GCP)

## 🎯 Objective

Set up the GCP Organization structure using the **org service account** (`sa-tf-org`)
created in Phase 0. This phase runs via SA impersonation — no human credentials needed
after bootstrap.

- Folder hierarchy (equivalent to AWS OUs)
- Projects (equivalent to AWS accounts)
- Organization policies (equivalent to AWS SCPs)
- Billing budget alerts

## 🔐 Authentication

This phase impersonates the `sa-tf-org` service account from Phase 0:

```hcl
provider "google" {
  impersonate_service_account = data.terraform_remote_state.bootstrap.outputs.org_sa_email
  region = var.default_region
}
```

State is stored in the seed project's GCS bucket:

```hcl
terraform {
  backend "gcs" {
    bucket = "bkt-prj-b-seed-XXXX-tfstate"  # from Phase 0 output
    prefix = "terraform/org"
  }
}
```

## 📋 What Gets Created

| Resource | Purpose | GCP Equivalent of |
|----------|---------|-------------------|
| Folders | Logical grouping | AWS OUs |
| Projects | Isolated environments | AWS Accounts |
| Org Policies | Guardrails | AWS SCPs |
| Billing Budgets | Cost control | AWS Budgets |

## 🏗️ Folder Structure

```
Organization ({org_domain})
├── {folder_prefix}-bootstrap/          ← created in Phase 0
│   ├── {project_prefix}-b-seed-XXXX
│   └── {project_prefix}-b-cicd-gh-XXXX
├── {folder_prefix}-platform/
│   ├── {project_prefix}-security       (project)
│   ├── {project_prefix}-log            (project)
│   └── {project_prefix}-shared         (project)
├── {folder_prefix}-workloads/
│   ├── {brand}/                        (folder per brand)
│   │   ├── {project_prefix}-{brand}-dev     (project)
│   │   ├── {project_prefix}-{brand}-stage   (project)
│   │   └── {project_prefix}-{brand}-prod    (project)
│   └── ...more brands (dynamic)
└── {folder_prefix}-sandbox/
    └── {project_prefix}-sandbox        (project)
```

> **Note:** In GCP, "folders" serve the same purpose as AWS OUs, and "projects" are equivalent to AWS accounts.
> All folder names use the `{folder_prefix}` and project names use `{project_prefix}` from Phase 0.

## 📝 Key Resources

```hcl
# Read bootstrap outputs
data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "terraform/bootstrap"
  }
}

locals {
  org_id          = data.terraform_remote_state.bootstrap.outputs.common_config.org_id
  billing_account = data.terraform_remote_state.bootstrap.outputs.common_config.billing_account
  parent          = data.terraform_remote_state.bootstrap.outputs.common_config.parent_id
  folder_prefix   = data.terraform_remote_state.bootstrap.outputs.common_config.folder_prefix
  project_prefix  = data.terraform_remote_state.bootstrap.outputs.common_config.project_prefix
}

# Folder hierarchy
resource "google_folder" "platform" {
  display_name = "${local.folder_prefix}-platform"
  parent       = local.parent
}

resource "google_folder" "workloads" {
  display_name = "${local.folder_prefix}-workloads"
  parent       = local.parent
}

resource "google_folder" "sandbox" {
  display_name = "${local.folder_prefix}-sandbox"
  parent       = local.parent
}

# Brand folders (dynamic)
resource "google_folder" "brand" {
  for_each     = { for b in var.brands : b.name => b }
  display_name = each.key
  parent       = google_folder.workloads.name
}

# Projects per brand×env (dynamic)
resource "google_project" "brand_env" {
  for_each = {
    for pair in flatten([
      for b in var.brands : [
        for e in b.envs : { brand = b.name, env = e }
      ]
    ]) : "${pair.brand}-${pair.env}" => pair
  }

  name            = "${local.project_prefix}-${each.key}"
  project_id      = "${local.project_prefix}-${each.key}"
  folder_id       = google_folder.brand[each.value.brand].name
  billing_account = local.billing_account
  deletion_policy = "PREVENT"

  labels = {
    brand       = each.value.brand
    environment = each.value.env
    managed-by  = "terraform"
  }
}
```

## 📋 Organization Policies (Key Examples)

| Policy | Effect | AWS Equivalent |
|--------|--------|----------------|
| `constraints/compute.disableSerialPortAccess` | Disable serial port | — |
| `constraints/iam.disableServiceAccountKeyCreation` | Force Workload Identity | SCP deny IAM keys |
| `constraints/compute.restrictSharedVpcSubnetworks` | Network isolation | SCP VPC guardrails |
| `constraints/gcp.resourceLocations` | Region restriction | SCP region deny |
| `constraints/sql.restrictPublicIp` | No public DBs | SCP RDS guardrails |

## ✅ Phase 1 Checklist

- [ ] Remote state from Phase 0 accessible
- [ ] Provider impersonating `sa-tf-org` successfully
- [ ] Folder hierarchy created ({folder_prefix}-platform, {folder_prefix}-workloads, {folder_prefix}-sandbox)
- [ ] Brand folders created dynamically under workloads
- [ ] Projects created per brand×env with {project_prefix} naming
- [ ] Platform projects created (security, log, shared)
- [ ] Organization policies applied
- [ ] Billing budgets configured
