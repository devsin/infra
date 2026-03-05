# GitHub Platform Management

## Overview

GitHub manages **source control, CI/CD, and repository configuration** for the organization. The current implementation has:

- **Org stack** — manages repositories, Actions secrets/variables, and deployment environments for the parent org.
- **Brand stack** — (scaffold only) planned for per-brand GitHub org management.

## Architecture

```
github/stacks/org                (parent org)
│
├── Repositories (via module)
│   └── infra, <brand>-api, <brand>-web, ...
│
├── Actions Secrets (org-level)
│   └── GCP_WIF_PROVIDER, GCP_ORG_ID, GCP_BILLING_ACCOUNT, MIRROR_PAT
│
├── Actions Variables (org-level)
│   └── GCP_BOOTSTRAP_SA, GCP_ORG_SA, GCP_STATE_BUCKET, GCP_BRANDS, ...
│
└── Deployment Environments
    └── gcp-bootstrap, gcp-org, ...

github/stacks/brand              (per-brand — scaffold only)
│
└── envs/<brand>.tfvars          (future)
```

> **Current state:** The org stack is fully implemented and active. The brand
> stack directory exists but has no Terraform files yet — it's reserved for
> managing per-brand GitHub organizations in the future.

## Directory Structure

```
github/
├── stacks/
│   ├── org/                             # Parent org settings + CI/CD config
│   │   ├── main.tf                      #   Repos via module, org data source
│   │   ├── actions.tf                   #   Secrets, variables, environments
│   │   ├── variables.tf                 #   Repos, secrets, variables, envs
│   │   ├── providers.tf
│   │   ├── backend.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── terraform.tfvars             #   (gitignored — real values)
│   │   └── terraform.tfvars.example     #   Sanitized example
│   │
│   └── brand/                           # Per-brand GitHub org (future)
│       └── envs/
│
└── modules/
    └── repository/                      # Reusable repo module
        ├── main.tf                      #   github_repository + branch protection
        ├── variables.tf
        └── outputs.tf
```

## Terraform Provider

```hcl
# versions.tf
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
```

## Authentication

```hcl
# providers.tf
provider "github" {
  owner = var.github_org
  token = var.github_token  # or export GITHUB_TOKEN="ghp_..."
}
```

> **Security:** Never commit tokens. Use `export GITHUB_TOKEN="ghp_..."`.

## Key Variables

### Org Stack

```hcl
variable "github_org" { type = string }

variable "repos" {
  type = map(object({
    description = optional(string, "")
    visibility  = optional(string, "private")
    topics      = optional(list(string), [])
    auto_init   = optional(bool, false)
    branch_protection = optional(object({
      required_reviews      = optional(number, 1)
      dismiss_stale_reviews = optional(bool, true)
      require_status_checks = optional(list(string), [])
      enforce_admins        = optional(bool, false)
    }), null)
  }))
}

variable "actions_secrets" {
  type      = map(string)
  sensitive = true
}

variable "actions_variables" {
  type = map(string)
}

variable "environments" {
  type    = list(string)
  default = []
}
```

### Example Org tfvars

```hcl
# github/stacks/org/terraform.tfvars.example
github_org = "<org-name>"

repos = {
  "infra" = {
    description = "Multi-cloud infrastructure — Terraform/OpenTofu"
    visibility  = "public"
    topics      = ["terraform", "opentofu", "infrastructure", "gcp", "aws"]
    branch_protection = {
      required_reviews      = 1
      dismiss_stale_reviews = true
    }
  }
}

actions_secrets = {
  GCP_WIF_PROVIDER    = ""   # → GCP Phase 0: tofu output -raw wif_provider_name
  GCP_ORG_ID          = ""   # → GCP Organization ID (numeric)
  GCP_BILLING_ACCOUNT = ""   # → Billing Account ID
  MIRROR_PAT          = ""   # → Fine-grained PAT for public mirror
}

actions_variables = {
  GCP_BOOTSTRAP_SA = ""      # → GCP Phase 0: tofu output -raw bootstrap_sa_email
  GCP_ORG_SA       = ""      # → GCP Phase 0: tofu output -raw org_sa_email
  GCP_STATE_BUCKET = ""      # → GCP Phase 0: seed_state_bucket_name
  GCP_BRANDS       = ""      # → JSON array of brand definitions
  CI_ENABLED       = "true"  # → Set to "true" to enable CI/CD workflows
}

environments = [
  "gcp-bootstrap",
  "gcp-org",
]
```

## What the Org Stack Creates

### Repositories (via `module.repos`)

Each repo in the `repos` map gets:
- `github_repository` — with description, visibility, topics
- `github_branch_protection` — optional, with required reviews and status checks

### Actions Secrets (`actions.tf`)

Org-level encrypted secrets for CI/CD pipelines. These store sensitive values
like GCP Workload Identity Federation provider, org ID, and billing account.

```hcl
resource "github_actions_organization_secret" "this" {
  for_each        = var.actions_secrets
  secret_name     = each.key
  visibility      = "all"
  plaintext_value = each.value
}
```

### Actions Variables (`actions.tf`)

Org-level non-secret variables for CI/CD. These store service account emails,
state bucket names, brand configs, and feature flags.

```hcl
resource "github_actions_organization_variable" "this" {
  for_each      = var.actions_variables
  variable_name = each.key
  visibility    = "all"
  value         = each.value
}
```

### Deployment Environments

Used for deploy tracking in the GitHub Actions UI:

```hcl
resource "github_repository_environment" "this" {
  for_each    = toset(var.environments)
  repository  = "infra"
  environment = each.value
}
```

## State Management

```bash
cd github/stacks/org
tofu init -reconfigure \
  -backend-config="bucket=<gcs-tfstate-bucket>" \
  -backend-config="prefix=terraform/github/org"

tofu plan
tofu apply
```

| Stack | State Prefix |
|-------|-------------|
| Org | `terraform/github/org` |
| Brand (future) | `terraform/github/brand/<brand>` |

## Deployment

```bash
cd github/stacks/org
export GITHUB_TOKEN="ghp_..."

tofu init -reconfigure \
  -backend-config="bucket=<gcs-tfstate-bucket>" \
  -backend-config="prefix=terraform/github/org"

tofu plan
tofu apply
```

> **Note:** The org stack uses `terraform.tfvars` (gitignored) instead of
> per-brand env files, since it manages a single org.

## What Gets Managed

| Resource | Managed? | Notes |
|----------|----------|-------|
| Repositories | Yes | Via reusable `repository` module |
| Branch protection rules | Yes | Required reviews, status checks |
| Actions secrets (org-level) | Yes | GCP WIF, org ID, billing, PAT |
| Actions variables (org-level) | Yes | SA emails, state bucket, brands JSON |
| Deployment environments | Yes | For deploy tracking in Actions UI |
| Org settings | No | Managed via GitHub dashboard |
| Teams / membership | No | Managed via GitHub dashboard (future) |
| Webhooks | No | Not currently needed |
| GitHub Actions workflows | No | Managed in each app's own repo |

## CI/CD Integration

The Actions secrets and variables created by this stack power CI/CD workflows
in other repos. The typical flow:

```
github/stacks/org (Terraform)
  ├── Creates: GCP_WIF_PROVIDER secret
  ├── Creates: GCP_BOOTSTRAP_SA variable
  └── Creates: GCP_STATE_BUCKET variable

Other repo workflows (.github/workflows/*.yml)
  ├── Uses: GCP_WIF_PROVIDER → authenticate to GCP via Workload Identity
  ├── Uses: GCP_BOOTSTRAP_SA → impersonate service account
  └── Uses: GCP_STATE_BUCKET → configure Terraform backend
```
