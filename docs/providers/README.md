# Providers

## Overview

This project manages infrastructure across **multiple providers** — cloud IaaS, PaaS wrappers, BaaS, and developer tools — all in one monorepo. Each provider is a **top-level directory** with a consistent `stacks/` + `modules/` structure.

Providers differ in two key ways:

| | Org-Scoped Providers | Brand-Scoped Providers |
|---|---|---|
| **Model** | Parent org owns one organization; brands are nested inside | Each brand has its own tenant; parent org is an admin member |
| **Examples** | AWS, GCP | GitHub, Railway, Supabase |
| **Stack pattern** | Phase-based (0–6), deployed once per org | Per-brand, deployed with `-var-file=envs/<brand>.tfvars` |
| **State** | Per-phase state keys | Per-brand state keys |

## Provider Categories

### Cloud Providers (IaaS)

Full infrastructure clouds — compute, networking, storage, identity. These follow the **phase-based 0–6 pattern** and the parent organization owns the cloud org/account.

| Provider | Directory | Status | Notes |
|----------|-----------|--------|-------|
| **AWS** | `aws/` | ✅ Active | Organizations, EKS, multi-account |
| **GCP** | `gcp/` | ✅ Active | GCP Org, GKE, multi-project |
| **DigitalOcean** | `digitalocean/` | 🔮 Future | IaaS + managed services |
| **Linode** | `linode/` | 🔮 Future | Akamai cloud compute |

### PaaS / Cloud Wrappers

Application deployment platforms — each **brand** has its own workspace/account.

| Provider | Directory | Status | Notes |
|----------|-----------|--------|-------|
| **Railway** | `railway/` | ✅ Active | Projects, services, environments |
| *(Render)* | — | — | Addable if needed |
| *(Fly.io)* | — | — | Addable if needed |

### BaaS / Backend Services

Managed backend platforms — each **brand** has its own project.

| Provider | Directory | Status | Notes |
|----------|-----------|--------|-------|
| **Supabase** | `supabase/` | 📋 Planned | Auth, DB, storage, edge functions |

### Developer Tools

Source control, CI/CD, and dev tooling — each **brand** has its own org.

| Provider | Directory | Status | Notes |
|----------|-----------|--------|-------|
| **GitHub** | `github/` | ✅ Active | Repos, Actions secrets/variables |

### CDN / Edge

DNS, CDN, edge security, and object storage — org stack creates zones, brand stack manages records.

| Provider | Directory | Status | Notes |
|----------|-----------|--------|-------|
| **Cloudflare** | `cloudflare/` | ✅ Active | DNS, R2 storage, TLS, WAF |

### Cross-Provider

Glue for multi-provider setups — VPN, DNS delegation, identity federation.

| Provider | Directory | Status | Notes |
|----------|-----------|--------|-------|
| **Hybrid** | `hybrid/` | 🔮 Future | Cross-cloud networking & identity |

## Phase-Based Providers (AWS, GCP)

Org-scoped clouds use a **6-phase layered pattern**. Each phase has its own Terraform state and deployment lifecycle:

| Phase | AWS | GCP | Scope |
|-------|-----|-----|-------|
| 0 | S3 + DynamoDB + KMS + OIDC | Bootstrap folder + Seed/CICD projects + GCS + KMS + SAs + WIF | Bootstrap |
| 1 | Org + OUs + Accounts + SCPs | Org + Folders + Projects + Org Policies | Organization |
| 1B | IAM Roles per account | Service Accounts per project | IAM Baseline |
| 2 | CloudTrail + GuardDuty + SSO | Audit Logs + SCC + Cloud Identity | Security |
| 3 | VPC + TGW + Endpoints + DNS | VPC + NAT + PGA + Cloud DNS | Networking |
| 4 | ECR + KMS + S3 + Secrets | Artifact Registry + KMS + GCS + SM | Platform |
| 5 | EKS + IRSA + Karpenter | GKE + Workload Identity + Autopilot | Compute |
| 6 | Argo CD + manifests | Argo CD + manifests | Workloads (GitOps) |

### Phase Dependencies

```
Phase 0: Bootstrap ─── state bucket, KMS, OIDC/WIF
         │
         ▼
Phase 1: Organization ─── accounts/projects, OUs/folders, SCPs/policies
         │
         ▼
Phase 1B: IAM Baseline ─── cross-account roles / SAs
         │
         ▼
Phase 2: Security ─── audit, threat detection, SSO
         │
         ▼
Phase 3: Networking ─── VPCs, DNS, connectivity   (per brand/env)
         │
         ▼
Phase 4: Platform ─── registries, KMS, storage     (per brand/env)
         │
         ▼
Phase 5: Compute ─── EKS/GKE clusters              (per brand/env)
         │
         ▼
Phase 6: Workloads ─── apps via GitOps              (per cluster)
```

**Phases 0–2** are global (applied once). **Phases 3–5** are per-brand/env driven by `.tfvars` files.

### Stack Structure (Phase-Based)

```
aws/stacks/                         gcp/stacks/
├── 0-bootstrap/                    ├── 0-bootstrap/
├── 1-org/                          ├── 1-org/
├── 2-security/                     ├── 2-security/
├── 3-networking/                   ├── 3-networking/
│   └── envs/                       │   └── envs/
│       ├── acme-dev.tfvars         │       ├── acme-dev.tfvars
│       └── acme-prod.tfvars        │       └── acme-prod.tfvars
├── 4-platform/                     ├── 4-platform/
│   └── envs/...                    │   └── envs/...
└── 5-eks/                          └── 5-gke/
    └── envs/...                        └── envs/...
```

## Brand-Scoped Providers (GitHub, Railway, Supabase)

Brand-scoped providers use a **per-brand stack** pattern. The same Terraform code is applied multiple times with different `.tfvars` files — one per brand:

### Stack Structure (Brand-Scoped)

```
github/stacks/                      railway/stacks/
├── org/          # admin org        └── brand/          # per-brand project
└── brand/        # per-brand org        └── envs/
    └── envs/                                ├── <brand-a>.tfvars
        ├── <brand-a>.tfvars                 └── <brand-b>.tfvars
        └── <brand-b>.tfvars

cloudflare/stacks/                  supabase/stacks/
├── org/          # zone creation    └── brand/          # per-brand project
│   └── envs/                                └── envs/
└── brand/        # DNS, R2, settings
    └── envs/         # <brand>-dev/prod
```

### Deployment Example

```bash
# Deploy GitHub config for a brand
cd github/stacks/brand
terraform init -backend-config="prefix=providers/github/brand/<brand>"
terraform plan -var-file=envs/<brand>.tfvars
terraform apply -var-file=envs/<brand>.tfvars
```

## State Management

All providers share the same state backend (GCS or S3), using different key prefixes:

| Provider | Stack | State Key Pattern |
|----------|-------|------------------|
| AWS | Phase 0 | `aws/bootstrap/terraform.tfstate` |
| AWS | Phase 3 (per-brand) | `aws/networking/<brand>/<env>/terraform.tfstate` |
| GCP | Phase 0 | `terraform/bootstrap/default.tfstate` |
| Cloudflare | Org | `terraform/cloudflare/org/<org>` |
| Cloudflare | Brand (prod) | `terraform/cloudflare/<brand>-prod` |
| Cloudflare | Brand (dev) | `terraform/cloudflare/<brand>-dev` |
| GitHub | Admin org | `terraform/github/org` |
| GitHub | Brand | `terraform/github/brand/<brand>` |
| Railway | Brand | `terraform/railway/<brand>` |
| Supabase | Brand | `terraform/supabase/brand/<brand>` |

## Adding a New Provider

To add a new provider (e.g., Fly.io):

1. **Create directory:** `flyio/stacks/` + `flyio/modules/` with `.gitkeep`
2. **Add docs:** `docs/providers/flyio/README.md`
3. **Update brands.yaml:** Add the provider field to the `platforms:` block
4. **Write Terraform:** Add provider, variables, resources in `stacks/brand/`
5. **Update this README:** Add to the appropriate category table above

## Provider Documentation

### Cloud Providers (IaaS)

| Provider | Docs |
|----------|------|
| AWS | [Phase 0](./aws/PHASE-0-BOOTSTRAP.md) · [Phase 1](./aws/PHASE-1-ORGANIZATION.md) · [Phase 1B](./aws/PHASE-1B-IAM-BASELINE.md) · [Phase 2](./aws/PHASE-2-SECURITY.md) · [Phase 3](./aws/PHASE-3-NETWORKING.md) · [Phase 4](./aws/PHASE-4-PLATFORM.md) · [Phase 5](./aws/PHASE-5-EKS.md) · [Phase 6](./aws/PHASE-6-WORKLOADS.md) |
| GCP | [Phase 0](./gcp/PHASE-0-BOOTSTRAP.md) · [Phase 1](./gcp/PHASE-1-ORGANIZATION.md) · [Phase 1B](./gcp/PHASE-1B-IAM-BASELINE.md) · [Phase 2](./gcp/PHASE-2-SECURITY.md) · [Phase 3](./gcp/PHASE-3-NETWORKING.md) · [Phase 4](./gcp/PHASE-4-PLATFORM.md) · [Phase 5](./gcp/PHASE-5-GKE.md) · [Phase 6](./gcp/PHASE-6-WORKLOADS.md) |
| Hybrid | [Overview](./hybrid/README.md) |

### Brand-Scoped Providers

| Provider | Docs |
|----------|------|
| Cloudflare | [Cloudflare Platform](./cloudflare/README.md) |
| GitHub | [GitHub Platform](./github/README.md) |
| Railway | [Railway Platform](./railway/README.md) |
| Supabase | [Supabase Platform](./supabase/README.md) |

## Terraform Provider Registry

| Provider | Terraform Provider | Version |
|----------|-------------------|---------|
| AWS | `hashicorp/aws` | `~> 6.0` |
| GCP | `hashicorp/google` + `hashicorp/google-beta` | `~> 6.0` |
| Cloudflare | `cloudflare/cloudflare` | `~> 5.0` |
| GitHub | `integrations/github` | `~> 6.0` |
| Railway | `terraform-community-providers/railway` | `~> 0.6` |
| Supabase | `supabase/supabase` | TBD |
| DigitalOcean | `digitalocean/digitalocean` | `~> 2.0` |
| Linode | `linode/linode` | `~> 2.0` |
