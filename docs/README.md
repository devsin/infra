# Multi-Cloud, Multi-Brand Infrastructure

This repository contains the Infrastructure as Code (IaC) for a **multi-cloud, multi-brand organization** managed with Terraform, scripts, and automation.

## 🌐 Provider Overview

Every provider — cloud, PaaS, BaaS, or dev tool — is a **top-level directory** with a consistent `stacks/` + `modules/` structure. Providers fall into two scope models:

### Org-Scoped Providers (phase-based)

The parent organization owns one org/account. Brands are nested inside as accounts, projects, or folders. These follow a **0–6 phase pattern**.

| Provider | Directory | Purpose | Status |
|----------|-----------|---------|--------|
| **AWS** | `aws/` | Organizations, EKS, multi-account | ✅ Active |
| **GCP** | `gcp/` | GCP Org, GKE, multi-project | ✅ Active |
| **DigitalOcean** | `digitalocean/` | IaaS + managed services | 🔮 Future |
| **Linode** | `linode/` | Akamai cloud compute | 🔮 Future |
| **Hybrid** | `hybrid/` | Cross-provider VPN, DNS, identity | 🔮 Future |

### Brand-Scoped Providers (per-brand stacks)

Each brand has its **own tenant** (org, workspace, or project). The parent company is an admin member. Stacks are deployed per-brand via `-var-file=envs/<brand>.tfvars`.

| Provider | Directory | Purpose | Status |
|----------|-----------|---------|--------|
| **GitHub** | `github/` | Orgs, repos, teams, branch protection | 📋 Planned |
| **Railway** | `railway/` | Projects, services, environments | 📋 Planned |
| **Supabase** | `supabase/` | Auth, DB, storage, edge functions | 📋 Planned |

> See the [Providers Guide](./providers/README.md) for full details, categories, and how to add new providers.

## 🏢 Organization Overview

This project manages infrastructure with:
- A **parent company** that owns multiple brands/products
- Each brand gets isolated environments (dev/stage/prod) per cloud
- Centralized platform services (security, logging, shared services)
- Google Workspace as the identity provider
- **Extensible** — add any provider by creating a top-level directory

All naming, accounts/projects, and brands are **driven by variables** — no hardcoded company or brand names.

## ⚙️ Key Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `org_name` | Parent organization name | `mycompany` |
| `org_domain` | Organization email domain | `mycompany.com` |
| `prefix` | Short prefix for resource naming | `mc` |
| `brands` | List of brand/product definitions | See `brands.yaml` |
| `primary_region` | Primary cloud region | `eu-west-1` |

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Architecture Overview](./architecture/OVERVIEW.md) | Multi-cloud architecture and design |
| [Account Strategy](./architecture/ACCOUNTS.md) | AWS account / GCP project structure |
| [OU Structure](./architecture/OU-STRUCTURE.md) | AWS OU / GCP folder hierarchy |
| [SCP Strategy](./architecture/SCP-STRATEGY.md) | AWS SCPs / GCP Org Policies |
| [Providers Guide](./providers/README.md) | All providers — phases, brands, adding new |
| [AWS Phases](./providers/aws/) | AWS phase-by-phase deployment |
| [GCP Phases](./providers/gcp/) | GCP phase-by-phase deployment |
| [GitHub](./providers/github/README.md) | GitHub org management |
| [Railway](./providers/railway/README.md) | Railway workspace management |
| [Supabase](./providers/supabase/README.md) | Supabase project management |

## 🎯 Design Principles

1. **Extensible Provider Model** — Any provider is just a top-level directory with `stacks/` + `modules/`
2. **Two Scope Models** — Org-scoped (phase-based) and brand-scoped (per-brand tfvars)
3. **Variable-Driven** — All company/brand names are configurable via variables
4. **Layered Infrastructure** — Each phase/stack is independently deployable/destroyable
5. **Account/Project-per-Environment** — Strong isolation between dev/stage/prod
6. **Security First** — SCPs, Org Policies, and guardrails from day one
7. **Google Workspace SSO** — Human access via native IdP integration
8. **Scale Cleanly** — Start minimal, grow without redesign

## 🗂️ Repository Structure

```
<repo>/
├── aws/                           # Cloud: Amazon Web Services
│   ├── stacks/                    #   Phase-based Terraform roots
│   │   ├── 0-bootstrap/           #     State backend, CI/CD OIDC
│   │   ├── 1-org/                 #     Organization, OUs, accounts, SCPs
│   │   ├── 2-security/            #     CloudTrail, GuardDuty, SSO
│   │   ├── 3-networking/          #     VPCs, TGW, DNS
│   │   ├── 4-platform/            #     ECR, KMS, S3
│   │   └── 5-eks/                 #     Kubernetes clusters
│   └── modules/
│
├── gcp/                           # Cloud: Google Cloud Platform
│   ├── stacks/
│   │   ├── 0-bootstrap/           #     Seed + CICD projects, SAs, WIF
│   │   ├── 1-org/                 #     Folders, projects, org policies
│   │   ├── 2-security/            #     Audit logs, SCC
│   │   ├── 3-networking/          #     VPC, NAT, Cloud DNS
│   │   ├── 4-platform/            #     Artifact Registry, KMS
│   │   └── 5-gke/                 #     GKE clusters
│   └── modules/
│
├── github/                        # Tool: GitHub
│   ├── stacks/
│   │   ├── org/                   #     Admin org settings
│   │   └── brand/                 #     Per-brand GitHub org
│   │       └── envs/              #       <brand>.tfvars (one per brand)
│   └── modules/
│
├── railway/                       # PaaS: Railway
│   ├── stacks/
│   │   └── brand/                 #     Per-brand workspace
│   │       └── envs/
│   └── modules/
│
├── supabase/                      # BaaS: Supabase
│   ├── stacks/
│   │   └── brand/                 #     Per-brand project
│   │       └── envs/
│   └── modules/
│
├── digitalocean/                  # Cloud: DigitalOcean (future)
│   ├── stacks/
│   └── modules/
│
├── linode/                        # Cloud: Linode / Akamai (future)
│   ├── stacks/
│   └── modules/
│
├── hybrid/                        # Cross-provider glue (future)
│   ├── stacks/
│   └── modules/
│
├── modules/                       # Shared, provider-agnostic modules
│   ├── naming/                    #   Naming convention logic
│   └── tagging/                   #   Tag/label normalization
│
├── docs/
│   ├── architecture/              #   Architecture decisions
│   └── providers/                 #   Per-provider documentation
│       ├── aws/                   #     AWS phase guides
│       ├── gcp/                   #     GCP phase guides
│       ├── github/                #     GitHub management
│       ├── railway/               #     Railway management
│       ├── supabase/              #     Supabase management
│       └── hybrid/                #     Cross-provider
│
├── scripts/                       # Helpers (scaffold, backend init)
├── brands.yaml                    # Brand definitions (provider-agnostic)
└── .gitignore
```

> **No brand-named folders anywhere in Terraform.** Brand names only exist
> inside `.tfvars` files and `brands.yaml`.

## 🚀 Quick Start

### Cloud Providers (phase-based)
1. Read the [Architecture Overview](./architecture/OVERVIEW.md) and [Providers Guide](./providers/README.md)
2. AWS: Follow [Phase 0](./providers/aws/PHASE-0-BOOTSTRAP.md) → deploy phases 0 → 5
3. GCP: Follow [Phase 0](./providers/gcp/PHASE-0-BOOTSTRAP.md) → deploy phases 0 → 5

### Brand-Scoped Providers
1. Read the [Providers Guide](./providers/README.md)
2. [GitHub](./providers/github/README.md) — set up orgs per brand
3. [Railway](./providers/railway/README.md) — set up workspaces per brand
4. [Supabase](./providers/supabase/README.md) — set up projects per brand

> All providers can be deployed independently. Brand-scoped providers use
> `-var-file=envs/<brand>.tfvars` for per-brand deployment.

## ➕ Adding a New Provider

1. Create `<provider>/stacks/` + `<provider>/modules/` at the repo root
2. Add docs at `docs/providers/<provider>/README.md`
3. Add the provider to `brands.yaml` schema if brand-scoped
4. Update the [Providers Guide](./providers/README.md)

## ⚠️ Important Notes

- **Destroy order:** Always destroy bottom-up (5 → 4 → 3 → 2 → 1 → 0) for phase-based providers
- **Account closure:** AWS accounts cannot be instantly deleted; closure has delays
- **State isolation:** Each phase/brand has its own Terraform state
- **Identity:** Human users authenticate via Google Workspace SSO; CI/CD uses GitHub OIDC
