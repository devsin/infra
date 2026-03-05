# Railway Platform Management

## Overview

[Railway](https://railway.app) is a PaaS used for deploying application services, databases, and scheduled jobs. Each brand gets **one Railway project** containing all services and environments.

This Terraform stack manages:
- Railway project (one per brand)
- Environments (dev, prod — first is default)
- Services within the project (API, web, database, workers)
- Environment variables per service per environment
- Custom domains per service per environment
- Volume mounts (persistent storage for databases)

## Architecture

```
Railway Workspace (per-brand token)
│
└── Project: <brand>
    ├── Environment: dev  (default)
    │   ├── Service: <brand>-api     → api-dev.<domain>
    │   ├── Service: <brand>-web     → dev.<domain>
    │   └── Service: <brand>-db      → PostgreSQL (volume-backed)
    │
    └── Environment: prod
        ├── Service: <brand>-api     → api.<domain>
        ├── Service: <brand>-web     → <domain>
        └── Service: <brand>-db      → PostgreSQL (volume-backed)
```

> **Key design:** One project per brand, multiple services inside.
> Environments are first-class Railway objects — the first environment
> in the list becomes the project default, additional ones are created
> via `railway_environment`.

## Directory Structure

```
railway/
├── stacks/
│   └── brand/                   # Per-brand Railway project
│       ├── main.tf              #   Project, environments, services, vars, domains
│       ├── variables.tf         #   Services map with vars/domains/volumes
│       ├── outputs.tf           #   Project ID, service IDs
│       ├── providers.tf
│       ├── backend.tf
│       ├── versions.tf
│       └── envs/
│           └── <brand>.tfvars   #   One file per brand (all envs inside)
│
└── modules/                     # (empty — all resources in main.tf)
```

## Terraform Provider

```hcl
# versions.tf
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "~> 0.6"
    }
  }
}
```

> **Note:** This is a community-maintained provider. Check the
> [Terraform Registry](https://registry.terraform.io/providers/terraform-community-providers/railway/latest)
> for the latest version and supported resources.

## Authentication

Railway uses an **API token** scoped to a workspace (team).

```hcl
# providers.tf
provider "railway" {
  token = var.token  # or export TF_VAR_token="..."
}
```

> **Security:** Never commit tokens. Use `export TF_VAR_token="..."`.
> Each brand workspace has its own API token.

## Key Variables

### Service Definition

Each service is defined as a map entry with per-environment variables and custom domains:

```hcl
variable "services" {
  type = map(object({
    source_repo    = optional(string, null)    # GitHub repo (e.g., "myorg/myapp")
    source_branch  = optional(string, null)    # Branch override
    source_image   = optional(string, null)    # Docker image (mutually exclusive with repo)
    root_directory = optional(string, null)     # Monorepo subdirectory
    config_path    = optional(string, null)     # railway.json/toml path
    cron_schedule  = optional(string, null)     # Cron expression if worker

    volume = optional(object({                 # Persistent volume (for databases)
      mount_path = string                      #   e.g., "/var/lib/postgresql/data"
      size_mb    = optional(number, 10240)     #   Default 10 GB
    }), null)

    # Variables: map of environment → map of key=value
    variables = optional(map(map(string)), {})
    #   e.g., { dev = { NODE_ENV = "development" }, prod = { NODE_ENV = "production" } }

    # Custom domains: map of environment → list of domains
    custom_domains = optional(map(list(string)), {})
    #   e.g., { dev = ["api-dev.mybrand.com"], prod = ["api.mybrand.com"] }
  }))
}
```

### Example Brand tfvars

```hcl
# railway/stacks/brand/envs/<brand>.tfvars
brand_name   = "<brand>"
environments = ["dev", "prod"]    # First is default
region       = "europe-west4"     # or us-west1, us-east4, etc.

services = {
  "<brand>-api" = {
    source_repo = "<github-org>/<brand>-api"

    variables = {
      dev = {
        PORT              = "8080"
        ENVIRONMENT       = "development"
        DATABASE_URL      = "${{<brand>-db.DATABASE_URL}}"
        CORS_ORIGIN       = "https://dev.<brand-domain>"
        PUBLIC_API_URL    = "https://api-dev.<brand-domain>"
      }
      prod = {
        PORT              = "8080"
        ENVIRONMENT       = "production"
        DATABASE_URL      = "${{<brand>-db.DATABASE_URL}}"
        CORS_ORIGIN       = "https://<brand-domain>"
        PUBLIC_API_URL    = "https://api.<brand-domain>"
      }
    }

    custom_domains = {
      dev  = ["api-dev.<brand-domain>"]
      prod = ["api.<brand-domain>"]
    }
  }

  "<brand>-web" = {
    source_repo = "<github-org>/<brand>-web"

    variables = {
      dev = {
        PUBLIC_API_URL = "https://api-dev.<brand-domain>"
      }
      prod = {
        PUBLIC_API_URL = "https://api.<brand-domain>"
      }
    }

    custom_domains = {
      dev  = ["dev.<brand-domain>"]
      prod = ["<brand-domain>"]
    }
  }

  "<brand>-db" = {
    source_image = "ghcr.io/railwayapp-templates/postgres-ssl:17"

    volume = {
      mount_path = "/var/lib/postgresql/data"
      size_mb    = 10240
    }

    variables = {
      dev = {
        POSTGRES_USER     = "<brand>"
        POSTGRES_DB       = "<brand>"
        POSTGRES_PASSWORD = "<generated>"
        PGDATA            = "/var/lib/postgresql/data/pgdata"
      }
      prod = {
        POSTGRES_USER     = "<brand>"
        POSTGRES_DB       = "<brand>"
        POSTGRES_PASSWORD = "<generated>"
        PGDATA            = "/var/lib/postgresql/data/pgdata"
      }
    }
  }
}
```

### Variable Interpolation

Railway supports inter-service variable references via `${{service.VAR}}` syntax.
This is especially useful for database connection strings:

```hcl
DATABASE_URL = "${{<brand>-db.DATABASE_URL}}"
```

> The `DATABASE_URL` is automatically generated by Railway's PostgreSQL
> template and exposed to other services via this reference syntax.

## Subdomain Strategy

Dev subdomains must be single-level to work with Cloudflare Free plan Universal SSL:

| Service | Dev | Prod |
|---------|-----|------|
| API | `api-dev.<domain>` | `api.<domain>` |
| Web | `dev.<domain>` | `<domain>` |
| CDN | `cdn-dev.<domain>` | `cdn.<domain>` |

> **Why not `dev.api.<domain>`?** Cloudflare Free plan Universal SSL only covers
> `*.<domain>`, not `*.*.<domain>`. Multi-level subdomains cause
> `ERR_SSL_VERSION_OR_CIPHER_MISMATCH`. See [Cloudflare docs](../cloudflare/README.md).

## Railway Concepts → Terraform Mapping

| Railway Concept | Terraform Resource | Notes |
|----------------|-------------------|-------|
| Workspace (Team) | N/A — pre-created | Token scopes to workspace |
| Project | `railway_project` | One per brand |
| Environment | `railway_environment` | First in list is default |
| Service | `railway_service` | API, web, DB, workers |
| Variables | `railway_variable` | Flattened: service × env × var |
| Custom Domain | `railway_custom_domain` | Flattened: service × env × domain |
| Volume | `railway_volume` | Persistent storage (e.g., PostgreSQL data) |

## How Resources Are Flattened

The `main.tf` flattens nested maps into flat `for_each` maps for Terraform:

```
services.variables:  { dev = { PORT = "8080" } }
  → flattened key:   "api:dev:PORT" → railway_variable
  
services.custom_domains: { dev = ["api-dev.mybrand.com"] }
  → flattened key:   "api:dev:0" → railway_custom_domain
```

This pattern avoids nested `dynamic` blocks and makes the state addressable.

## State Management

```bash
cd railway/stacks/brand
tofu init -reconfigure \
  -backend-config="bucket=<gcs-tfstate-bucket>" \
  -backend-config="prefix=terraform/railway/<brand>"

tofu plan  -var-file=envs/<brand>.tfvars
tofu apply -var-file=envs/<brand>.tfvars
```

| Stack | State Prefix |
|-------|-------------|
| Brand | `terraform/railway/<brand>` |

> **Note:** All environments for a brand share one state file.
> The per-env variable/domain separation is handled via the flattened maps.

## Deployment

```bash
cd railway/stacks/brand
export TF_VAR_token="<railway-api-token>"

tofu init -reconfigure \
  -backend-config="bucket=<gcs-tfstate-bucket>" \
  -backend-config="prefix=terraform/railway/<brand>"

tofu plan  -var-file=envs/<brand>.tfvars
tofu apply -var-file=envs/<brand>.tfvars
```

### Importing Existing Resources

If Railway resources already exist (created via dashboard or CLI), import them before applying. See [IMPORT.md](../../../railway/stacks/brand/IMPORT.md) for detailed import commands.

## What Gets Managed

| Resource | Managed? | Notes |
|----------|----------|-------|
| Workspaces (Teams) | No | Created manually; token scoped to workspace |
| Projects | Yes | One per brand |
| Environments | Yes | First is default; others created via `railway_environment` |
| Services | Yes | Linked to GitHub repos or Docker images |
| Environment variables | Yes | Per-service, per-environment |
| Custom domains | Yes | Per-service, per-environment |
| Volumes | Yes | Persistent storage for databases |
| Deployments | No | Triggered by git push (auto-deploy) or Railway CLI |
| Billing | No | Managed in Railway dashboard |

## Considerations

### Railway vs AWS/GCP Compute

Railway is ideal for:
- Rapid prototyping and dev/staging environments
- Simple web apps and APIs that don't need K8s complexity
- Brands that start small before graduating to EKS/GKE
- Go/Node.js/Python services with auto-deploy from GitHub

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
