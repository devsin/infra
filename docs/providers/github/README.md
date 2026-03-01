# GitHub Platform Management

## Overview

Each brand in the organization has its **own GitHub organization**. The parent company is an **owner/admin** in every brand org, but each org is a separate tenant.

This Terraform stack manages:
- GitHub organization settings
- Repository creation and configuration
- Team structure and membership
- Branch protection rules
- Repository secrets and variables (for Actions)
- Webhooks and integrations

## Architecture

```
<parent-org> (admin)
│
├── github.com/<brand-a>-org     ← Brand A GitHub org
│   ├── repos, teams, settings
│   └── managed via envs/<brand-a>.tfvars
│
├── github.com/<brand-b>-org     ← Brand B GitHub org
│   ├── repos, teams, settings
│   └── managed via envs/<brand-b>.tfvars
│
└── github.com/<parent-org>      ← Admin org (optional Terraform)
    └── managed via stacks/org/
```

> **Key point:** Unlike AWS/GCP where one org contains all brands, each brand's
> GitHub org is completely independent. The parent org is an admin *member*
> in each, not the *container*.

## Directory Structure

```
github/
├── stacks/
│   ├── org/                     # Admin org settings (parent org)
│   │   ├── main.tf              #   Org-level settings, admin team
│   │   ├── variables.tf
│   │   ├── providers.tf
│   │   ├── backend.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── versions.tf
│   │
│   └── brand/                   # Per-brand GitHub org management
│       ├── main.tf              #   Repos, teams, branch protection
│       ├── repos.tf             #   Repository definitions
│       ├── teams.tf             #   Team structure
│       ├── variables.tf
│       ├── providers.tf
│       ├── backend.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── envs/                #   One tfvars per brand
│           ├── <brand-a>.tfvars
│           └── <brand-b>.tfvars
│
└── modules/
    ├── repository/              # Reusable repo module
    └── team/                    # Reusable team module
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

The GitHub provider authenticates using a **GitHub App** or **Personal Access Token (PAT)** with admin scope on the target organization.

### Option A: GitHub App (Recommended)

```hcl
# providers.tf
provider "github" {
  owner = var.github_org

  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem_file  # or use GITHUB_APP_PEM_FILE env var
  }
}
```

### Option B: Personal Access Token

```hcl
# providers.tf
provider "github" {
  owner = var.github_org
  token = var.github_token  # or use GITHUB_TOKEN env var
}
```

> **Security:** Never commit tokens. Use environment variables or a secrets manager.
> For CI/CD, the token should be stored in the infrastructure secrets manager (AWS SSM / GCP Secret Manager)
> and injected at plan/apply time.

## Key Variables

### Brand Stack (`stacks/brand/`)

```hcl
# variables.tf
variable "github_org" {
  description = "GitHub organization name for this brand"
  type        = string
}

variable "brand_name" {
  description = "Brand name (must match brands.yaml)"
  type        = string
}

variable "default_branch" {
  description = "Default branch name for new repos"
  type        = string
  default     = "main"
}

variable "repos" {
  description = "Map of repositories to create"
  type = map(object({
    description    = optional(string, "")
    visibility     = optional(string, "private")
    has_issues     = optional(bool, true)
    has_wiki       = optional(bool, false)
    has_projects   = optional(bool, false)
    template       = optional(string, null)
    topics         = optional(list(string), [])
    default_branch = optional(string, "main")
    branch_protection = optional(object({
      required_reviews       = optional(number, 1)
      dismiss_stale_reviews  = optional(bool, true)
      require_status_checks  = optional(list(string), [])
      enforce_admins         = optional(bool, false)
    }), {})
  }))
  default = {}
}

variable "teams" {
  description = "Map of teams to create"
  type = map(object({
    description = optional(string, "")
    privacy     = optional(string, "closed")
    members     = optional(list(string), [])
    maintainers = optional(list(string), [])
    repos       = optional(map(string), {})  # repo_name => permission
  }))
  default = {}
}
```

### Example Brand tfvars

```hcl
# envs/<brand>.tfvars
github_org = "<brand>-org"
brand_name = "<brand>"

repos = {
  "<brand>-web" = {
    description = "Web application"
    visibility  = "private"
    topics      = ["nextjs", "typescript"]
    branch_protection = {
      required_reviews      = 1
      dismiss_stale_reviews = true
      require_status_checks = ["ci/test", "ci/lint"]
    }
  }
  "<brand>-api" = {
    description = "API service"
    visibility  = "private"
    topics      = ["api", "typescript"]
  }
  "<brand>-infra" = {
    description = "Infrastructure overlays"
    visibility  = "private"
    topics      = ["terraform", "infrastructure"]
  }
}

teams = {
  "developers" = {
    description = "Core developers"
    privacy     = "closed"
    members     = []  # populated after org setup
    repos = {
      "<brand>-web" = "push"
      "<brand>-api" = "push"
    }
  }
  "admins" = {
    description = "Organization admins"
    privacy     = "closed"
    repos = {
      "<brand>-web"   = "admin"
      "<brand>-api"   = "admin"
      "<brand>-infra" = "admin"
    }
  }
}
```

## State Management

```hcl
# backend.tf (brand stack)
terraform {
  backend "gcs" {
    bucket = "<seed-project-state-bucket>"
    prefix = "providers/github/brand/${var.brand_name}"
  }
}
```

> **Note:** Since `var` is not allowed in backend config, use either:
> - Terraform workspaces (one per brand)
> - `-backend-config` flag at init time
> - A wrapper script that sets the prefix dynamically

```bash
# Example: init with dynamic backend key
terraform init \
  -backend-config="prefix=providers/github/brand/<brand>"
```

## Deployment

```bash
# Manage the admin org (parent org)
cd github/stacks/org
terraform init
terraform plan
terraform apply

# Manage a brand's GitHub org
cd github/stacks/brand
terraform init -backend-config="prefix=providers/github/brand/<brand>"
terraform plan -var-file=envs/<brand>.tfvars
terraform apply -var-file=envs/<brand>.tfvars
```

## What Gets Managed

| Resource | Managed by Terraform? | Notes |
|----------|----------------------|-------|
| Org settings (name, description, permissions) | ✅ Yes | Via `github_organization_settings` |
| Repositories | ✅ Yes | Creation, settings, visibility |
| Branch protection rules | ✅ Yes | Required reviews, status checks |
| Teams | ✅ Yes | Structure and repo permissions |
| Team membership | ⚠️ Partial | Initial setup; day-to-day via GitHub UI |
| Actions secrets/variables | ✅ Yes | Org-level and repo-level |
| Webhooks | ✅ Yes | If needed for CI/CD integrations |
| GitHub Actions workflows | ❌ No | Managed in each app's own repo |
| Issue templates, CODEOWNERS | ❌ No | Managed in each app's own repo |

## CI/CD Integration

Platform stacks can be deployed via GitHub Actions in the `nd-infra` repo:

```yaml
# .github/workflows/github-platform.yml
name: GitHub Platform
on:
  push:
    branches: [main]
    paths: ['github/**']
  pull_request:
    paths: ['github/**']

jobs:
  plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        brand: [<brand-a>, <brand-b>]  # from brands.yaml
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: |
          cd github/stacks/brand
          terraform init -backend-config="prefix=providers/github/brand/${{ matrix.brand }}"
          terraform plan -var-file=envs/${{ matrix.brand }}.tfvars
```
