# Railway Platform Management

## Overview

Each brand has its **own Railway workspace**. The parent company is an admin/owner in each workspace, but they are separate tenants — not nested under one parent workspace.

[Railway](https://railway.app) is a PaaS used for deploying application services, databases, and scheduled jobs. This Terraform stack manages:
- Railway projects (one per app/service)
- Services within projects
- Environment variables and secrets
- Custom domains
- Volume mounts
- TCP proxies (if needed)

## Architecture

```
<parent-org> (admin)
│
├── Railway Workspace: <brand-a>
│   ├── Project: <brand-a>-web     (production, staging envs)
│   ├── Project: <brand-a>-api     (production, staging envs)
│   ├── Project: <brand-a>-workers (production, staging envs)
│   └── managed via envs/<brand-a>.tfvars
│
├── Railway Workspace: <brand-b>
│   ├── Project: <brand-b>-app     (production, staging envs)
│   ├── Project: <brand-b>-ingest  (production, staging envs)
│   └── managed via envs/<brand-b>.tfvars
│
└── (<parent-org>'s own workspace — if any)
```

> **Key point:** Railway workspaces are the brand-level isolation boundary.
> Each workspace has its own billing, team, and token scope.

## Directory Structure

```
railway/
├── stacks/
│   └── brand/                   # Per-brand Railway workspace management
│       ├── main.tf              #   Projects, services, environments
│       ├── projects.tf          #   Project definitions
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
    ├── project/                 # Reusable Railway project module
    └── service/                 # Reusable Railway service module
```

## Terraform Provider

Railway has a community Terraform provider. Evaluate the latest options:

```hcl
# versions.tf
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "~> 0.4"
    }
  }
}
```

> **Note:** The Railway Terraform provider is community-maintained. Check
> [registry.terraform.io](https://registry.terraform.io/providers/terraform-community-providers/railway/latest)
> for the latest version and supported resources. If the provider is too limited,
> consider using Railway's GraphQL API via `null_resource` + `local-exec`, or
> managing Railway via their CLI in CI/CD instead.

## Authentication

Railway uses **API tokens** scoped to a workspace (team).

```hcl
# providers.tf
provider "railway" {
  token = var.railway_token  # or use RAILWAY_TOKEN env var
}
```

> **Security:** Never commit tokens. Use environment variables or a secrets manager.
> Each brand workspace has its own API token.

## Key Variables

```hcl
# variables.tf
variable "brand_name" {
  description = "Brand name (must match brands.yaml)"
  type        = string
}

variable "railway_token" {
  description = "Railway API token for the brand's workspace"
  type        = string
  sensitive   = true
}

variable "projects" {
  description = "Map of Railway projects to create"
  type = map(object({
    description  = optional(string, "")
    environments = optional(list(string), ["production", "staging"])
    services = optional(map(object({
      source_repo  = optional(string, null)   # GitHub repo (auto-deploy)
      source_image = optional(string, null)    # Docker image
      num_replicas = optional(number, 1)
      start_command = optional(string, null)
      healthcheck_path = optional(string, null)
      variables = optional(map(string), {})
      domains   = optional(list(string), [])   # Custom domains
    })), {})
  }))
  default = {}
}
```

### Example Brand tfvars

```hcl
# envs/<brand>.tfvars
brand_name = "<brand>"

projects = {
  "<brand>-web" = {
    description  = "Web application"
    environments = ["production", "staging"]
    services = {
      "web" = {
        source_repo    = "<brand>-org/<brand>-web"
        num_replicas   = 1
        healthcheck_path = "/api/health"
        domains = ["<brand>.com", "www.<brand>.com"]
        variables = {
          NODE_ENV = "production"
        }
      }
    }
  }
  "<brand>-api" = {
    description  = "API backend"
    environments = ["production", "staging"]
    services = {
      "api" = {
        source_repo    = "<brand>-org/<brand>-api"
        healthcheck_path = "/health"
        domains = ["api.<brand>.com"]
      }
      "postgres" = {
        # Railway managed Postgres plugin
      }
      "redis" = {
        # Railway managed Redis plugin
      }
    }
  }
}
```

## Railway Concepts → Terraform Mapping

| Railway Concept | Terraform Resource | Notes |
|----------------|-------------------|-------|
| Workspace (Team) | N/A — pre-created | Token scopes to workspace |
| Project | `railway_project` | Groups related services |
| Environment | `railway_project` environments | production, staging |
| Service | `railway_service` | Web, API, worker, database |
| Variables | `railway_variable` | Per-service, per-environment |
| Custom Domain | `railway_custom_domain` | Attach to a service |
| Volume | `railway_volume` | Persistent storage |
| TCP Proxy | `railway_tcp_proxy` | Expose non-HTTP services |

## State Management

```bash
# Init with brand-specific state key
cd railway/stacks/brand
terraform init -backend-config="prefix=providers/railway/brand/<brand>"
terraform plan -var-file=envs/<brand>.tfvars
```

## Deployment

```bash
# Deploy Railway config for a brand
cd railway/stacks/brand
terraform init -backend-config="prefix=providers/railway/brand/<brand>"
terraform plan -var-file=envs/<brand>.tfvars
terraform apply -var-file=envs/<brand>.tfvars

# Deploy another brand
terraform init -reconfigure -backend-config="prefix=providers/railway/brand/<brand-b>"
terraform plan -var-file=envs/<brand-b>.tfvars
terraform apply -var-file=envs/<brand-b>.tfvars
```

## What Gets Managed

| Resource | Managed by Terraform? | Notes |
|----------|----------------------|-------|
| Workspaces (Teams) | ❌ No | Created manually, token scoped to workspace |
| Projects | ✅ Yes | Created and configured |
| Services | ✅ Yes | Linked to GitHub repos or Docker images |
| Environment variables | ✅ Yes | Per-service, per-environment |
| Custom domains | ✅ Yes | Attached to services |
| Volumes | ✅ Yes | Persistent storage for databases |
| Deployments | ❌ No | Triggered by git push (auto-deploy) or Railway CLI |
| Billing | ❌ No | Managed in Railway dashboard |

## Considerations

### Railway vs AWS/GCP Compute

Railway is ideal for:
- Rapid prototyping and dev/staging environments
- Simple web apps and APIs that don't need K8s complexity
- Brands that start small before graduating to EKS/GKE

Railway is NOT ideal for:
- High-compliance workloads (use AWS/GCP)
- Workloads needing VPC/network isolation
- Cost-sensitive high-traffic production (compute pricing)

### Migration Path

Brands can start on Railway and migrate to EKS/GKE later:

```
Railway (start)  →  Containerized on EKS/GKE (scale)
```

The infrastructure supports both — Railway for lightweight deployments, AWS/GCP for production-grade infrastructure.
