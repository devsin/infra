# Phase 1B: IAM Baseline (GCP)

## 🎯 Objective

Establish consistent IAM bindings across all GCP projects created in Phase 1.
Unlike the old pattern, **Terraform automation SAs already exist** from Phase 0
(granular per-phase SAs in the seed project). This phase focuses on:

- Breakglass group binding in each project (emergency admin access)
- Per-project audit logging configuration
- Workload Identity bindings for application SAs (optional, per-project)
- Additional project-level IAM roles for the Phase 0 SAs

## 🔐 Authentication

This phase impersonates the `sa-tf-org` service account from Phase 0:

```hcl
provider "google" {
  impersonate_service_account = data.terraform_remote_state.bootstrap.outputs.org_sa_email
  region = var.default_region
}

terraform {
  backend "gcs" {
    bucket = "bkt-prj-b-seed-XXXX-tfstate"  # from Phase 0 output
    prefix = "terraform/iam-baseline"
  }
}
```

## 📋 What Gets Created

| Resource | Purpose | Scope |
|----------|---------|-------|
| Breakglass group binding | Emergency admin access | Per project |
| Audit log configuration | API activity logging | Per project |
| Phase SA project-level roles | Per-phase SA gets roles on relevant projects | Per project |

> **Note:** The `sa-tf-*` automation service accounts are already created in Phase 0's
> seed project. This phase does NOT create per-project SAs — it grants the
> existing Phase 0 SAs access to the projects created in Phase 1.

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

data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "terraform/org"
  }
}

# Breakglass access via Google Workspace group
resource "google_project_iam_member" "breakglass" {
  for_each = data.terraform_remote_state.org.outputs.all_project_ids

  project = each.value
  role    = "roles/owner"
  member  = "group:breakglass@${var.org_domain}"
}

# Grant env SA access to workload projects
resource "google_project_iam_member" "env_sa_project_access" {
  for_each = data.terraform_remote_state.org.outputs.workload_project_ids

  project = each.value
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${data.terraform_remote_state.bootstrap.outputs.env_sa_email}"
}
```

## 🔑 Foundation Pattern IAM Model

With the foundation pattern from Phase 0, IAM is structured differently:

| Concern | Old Pattern | Foundation Pattern |
|---------|------------|-------------------|
| Terraform automation | Per-project SA with `roles/editor` | Granular Phase 0 SAs with least-privilege |
| CI/CD identity | Single WIF → single SA | WIF → per-phase SA impersonation |
| Emergency access | Per-project IAM role | Google Group + IAM binding |
| Cross-project access | SA key + impersonation | WIF → SA → impersonation chain |

### SA → Phase Mapping

| Phase | SA (from Phase 0) | What It Manages |
|-------|-------------------|-----------------|
| 0 - Bootstrap | `sa-tf-bootstrap` | Seed project, CI/CD project, KMS, state bucket |
| 1 - Organization | `sa-tf-org` | Folders, projects, org policies |
| 1B - IAM Baseline | `sa-tf-org` | Project-level IAM bindings (this phase) |
| 2 - Security | `sa-tf-env` | Audit logs, SCC, Cloud Identity |
| 3 - Networking | `sa-tf-net` | VPC, NAT, DNS, firewall rules |
| 4+ - Platform/Workloads | `sa-tf-proj` | Artifact Registry, KMS, GKE, apps |

## 🔑 GCP vs AWS IAM Comparison

| Concept | AWS | GCP |
|---------|-----|-----|
| Cross-account role | IAM Role + AssumeRole | SA impersonation (via Phase 0 SAs) |
| Emergency access | IAM Role + trust policy | Google Group + IAM binding |
| CI/CD identity | OIDC + IAM Role | WIF → Phase SA impersonation |
| Permission boundary | Permission Boundary policy | — (use Org Policies instead) |

## ✅ Phase 1B Checklist

- [ ] Breakglass group binding in each project
- [ ] Phase SAs granted appropriate project-level roles
- [ ] Audit logging configured per project
- [ ] GitHub Actions can impersonate per-phase SAs successfully
