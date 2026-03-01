# Architecture Overview

## � Multi-Cloud Strategy

This repository manages infrastructure across **multiple cloud platforms** using a consistent phase-based approach. Each cloud is self-contained, but follows the same layered pattern so the mental model is identical.

### Org-Scoped (phase-based)

| Provider | Directory | Status | Purpose |
|----------|-----------|--------|---------|
| **AWS** | `aws/` | ✅ Active | Primary cloud — Organizations, EKS |
| **GCP** | `gcp/` | ✅ Active | Secondary cloud — GCP Org, GKE |
| **DigitalOcean** | `digitalocean/` | 🔮 Future | IaaS + managed services |
| **Linode** | `linode/` | 🔮 Future | Akamai cloud compute |
| **Hybrid** | `hybrid/` | 🔮 Future | Cross-provider networking & identity |

### Brand-Scoped (per-brand stacks)

Each brand has its **own tenant** — the parent company is an admin member:

| Provider | Directory | Status | Purpose |
|----------|-----------|--------|---------|
| **GitHub** | `github/` | 📋 Planned | Per-brand GitHub org management |
| **Railway** | `railway/` | 📋 Planned | Per-brand PaaS (projects, services) |
| **Supabase** | `supabase/` | 📋 Planned | Per-brand BaaS (auth, DB, storage) |

> See the [Providers Guide](../providers/README.md) for full details and how to add new providers.

> All names use the convention `{prefix}-<purpose>`. Replace `{prefix}` with your project prefix (e.g. `mc`), and `{brand}` with each brand name defined in `brands.yaml`.

## 🎯 Target End-State

### AWS Organization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     AWS Organization ({prefix}-mgmt)                        │
│                           {org_domain}                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │   Platform OU   │  │  Workloads OU   │  │       Sandbox OU            │ │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────────────────┤ │
│  │                 │  │                 │  │                             │ │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────────────────┐  │ │
│  │  │ Security  │  │  │  │  <brand>  │  │  │  │   {prefix}-sandbox    │  │ │
│  │  │    OU     │  │  │  │    OU     │  │  │  │   (experimentation)   │  │ │
│  │  ├───────────┤  │  │  ├───────────┤  │  │  └───────────────────────┘  │ │
│  │  │{prefix}-  │  │  │  │ dev/stage │  │  │                             │ │
│  │  │ security  │  │  │  │   prod    │  │  └─────────────────────────────┘ │
│  │  │{prefix}-  │  │  │  └───────────┘  │                                  │
│  │  │   log     │  │  │                 │                                  │
│  │  └───────────┘  │  │  ┌ ─ ─ ─ ─ ─ ┐  │                                  │
│  │                 │  │     ...more      │                                  │
│  │  ┌───────────┐  │  │     brands       │                                  │
│  │  │  Shared   │  │  │     (dynamic) │  │                                  │
│  │  │ Services  │  │  │  └ ─ ─ ─ ─ ─ ┘  │                                  │
│  │  │    OU     │  │  │                 │                                  │
│  │  ├───────────┤  │  └─────────────────┘                                  │
│  │  │{prefix}-  │  │                                                       │
│  │  │  shared   │  │                                                       │
│  │  └───────────┘  │                                                       │
│  │                 │                                                       │
│  └─────────────────┘                                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### GCP Organization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     GCP Organization ({org_domain})                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌───────────┐ │
│  │ {fldr}-bootstrap  │ │ {fldr}-platform  │ │ {fldr}-workloads │ │{fldr}-    │ │
│  ├──────────────────┤ ├─────────────────┤ ├─────────────────┤ │ sandbox   │ │
│  │                  │ │                 │ │                 │ ├───────────┤ │
│  │ {prj}-b-seed     │ │ {prj}-security  │ │  ┌───────────┐  │ │ {prj}-    │ │
│  │   (state, KMS,   │ │   (project)     │ │  │  <brand>  │  │ │  sandbox  │ │
│  │    SAs)          │ │                 │ │  │  folder   │  │ │ (project) │ │
│  │                  │ │ {prj}-log       │ │  ├───────────┤  │ │           │ │
│  │ {prj}-b-cicd-gh  │ │   (project)     │ │  │ dev/stage │  │ └───────────┘ │
│  │   (WIF pool)     │ │                 │ │  │   prod    │  │               │
│  │                  │ │ {prj}-shared    │ │  │ (projects)│  │               │
│  └──────────────────┘ │   (project)     │ │  └───────────┘  │               │
│                       │                 │ │                 │               │
│                       └─────────────────┘ │  ┌ ─ ─ ─ ─ ─ ┐  │               │
│                                           │     ...more      │               │
│                                           │     brands       │               │
│                                           │  └ ─ ─ ─ ─ ─ ┘  │               │
│                                           │                 │               │
│                                           └─────────────────┘               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

> `{fldr}` = `folder_prefix` (default: `fldr`), `{prj}` = `project_prefix` (default: `prj`).
> The bootstrap folder + seed/cicd projects are created in Phase 0.

## 🏗️ Layered Architecture

The infrastructure is built in **6 distinct layers**, each with its own Terraform state and deployment lifecycle. The same layer pattern applies to both AWS and GCP:

### Layer Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Layer 6: Workloads (GitOps)                  │
│            Kubernetes manifests, Helm charts, Apps              │
│                     (cloud-agnostic)                            │
├──────────────────────────────┬──────────────────────────────────┤
│     Layer 5: EKS (AWS)       │      Layer 5: GKE (GCP)         │
│  Clusters, Node Groups, IRSA │  Clusters, Pools, Workload ID   │
├──────────────────────────────┼──────────────────────────────────┤
│   Layer 4: Platform (AWS)    │    Layer 4: Platform (GCP)       │
│     ECR, KMS, S3, Secrets    │   Artifact Reg, KMS, GCS, SM    │
├──────────────────────────────┼──────────────────────────────────┤
│   Layer 3: Networking (AWS)  │    Layer 3: Networking (GCP)     │
│   VPCs, TGW, Endpoints, DNS │   VPCs, NAT, PGA, Cloud DNS     │
├──────────────────────────────┼──────────────────────────────────┤
│   Layer 2: Security (AWS)    │    Layer 2: Security (GCP)       │
│ CloudTrail, GuardDuty, SSO   │   Audit Logs, SCC, Identity     │
├──────────────────────────────┼──────────────────────────────────┤
│   Layer 1: Organization (AWS)│   Layer 1: Organization (GCP)    │
│   OUs, Accounts, SCPs        │   Folders, Projects, Org Policies│
├──────────────────────────────┼──────────────────────────────────┤
│   Layer 0: Bootstrap (AWS)   │   Layer 0: Bootstrap (GCP)       │
│   S3, DynamoDB, KMS, OIDC    │   Folder, Seed+CICD projects,    │
│                              │   GCS, KMS, SAs, WIF             │
└──────────────────────────────┴──────────────────────────────────┘
```

### Cross-Cloud Equivalents

| Layer | AWS | GCP |
|-------|-----|-----|
| 0 - Bootstrap | S3 + DynamoDB + KMS | Bootstrap folder + Seed project (GCS, KMS) + CICD project (WIF) + 5 granular SAs |
| 1 - Organization | OUs + Accounts + SCPs | Folders + Projects + Org Policies |
| 2 - Security | CloudTrail + GuardDuty + Identity Center | Audit Logs + SCC + Cloud Identity |
| 3 - Networking | VPC + TGW + VPC Endpoints | VPC + Cloud NAT + Private Google Access |
| 4 - Platform | ECR + KMS + S3 | Artifact Registry + KMS + GCS |
| 5 - Compute | EKS + IRSA | GKE + Workload Identity |
| 6 - Workloads | Argo CD (cloud-agnostic) | Argo CD (cloud-agnostic) |

### Layer Characteristics

| Layer | Scope | Change Frequency | Blast Radius |
|-------|-------|------------------|--------------|
| 0 - Bootstrap | Global | Very Rare | Critical |
| 1 - Organization | Global | Rare | High |
| 2 - Security | Global/Per-Account | Rare | High |
| 3 - Networking | Per-Account/Region | Occasional | Medium |
| 4 - Platform | Per-Account/Region | Occasional | Medium |
| 5 - EKS | Per-Account/Region | Regular | Low-Medium |
| 6 - Workloads | Per-Cluster | Frequent | Low |

## 🌍 Multi-Region Strategy

### Primary Region
- **`var.primary_region`** (e.g. `eu-west-1`) — Main workloads

### Secondary Region (DR/Compliance)
- **`var.dr_region`** (e.g. `eu-central-1`) — Disaster Recovery

### Region Usage by Account Type

| Account Type | Primary Region | Secondary Region |
|--------------|----------------|------------------|
| Platform (security, log, shared) | `var.primary_region` | `var.dr_region` (DR only) |
| Workload Dev | `var.primary_region` | ❌ |
| Workload Stage | `var.primary_region` | ❌ |
| Workload Prod | `var.primary_region` | `var.dr_region` (DR) |

## 🔐 Security Architecture

### Identity & Access

| Method | Used For | Provider |
|--------|----------|----------|
| **Google Workspace SSO** | Human access (console & CLI) | IAM Identity Center + Google Workspace IdP |
| **GitHub OIDC** | CI/CD pipeline access | GitHub Actions → WIF → per-phase SA impersonation |
| **Breakglass roles** | Emergency access | IAM role with MFA requirement |

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────┐
│                        SCPs (Organization)                   │
│    Deny root, Deny leaving org, Block public S3, etc.       │
├─────────────────────────────────────────────────────────────┤
│                    IAM Boundaries (Account)                  │
│         Permission boundaries, Role restrictions             │
├─────────────────────────────────────────────────────────────┤
│                  Network Controls (VPC)                      │
│      Security Groups, NACLs, VPC Endpoints                   │
├─────────────────────────────────────────────────────────────┤
│                  Workload Security (K8s)                     │
│    Pod Security, Network Policies, IRSA, Secrets             │
└─────────────────────────────────────────────────────────────┘
```

### Central Security Services

| Service | Location | Purpose |
|---------|----------|---------|
| CloudTrail (Org Trail) | `{prefix}-security` (delegated admin) | Audit logging |
| AWS Config | `{prefix}-security` (aggregator) | Compliance |
| GuardDuty | `{prefix}-security` (delegated admin) | Threat detection |
| Security Hub | `{prefix}-security` (delegated admin) | Security posture |
| Log Archive | `{prefix}-log` | Central log storage |
| IAM Identity Center | `{prefix}-mgmt` | SSO via Google Workspace |

## 🌐 DNS Architecture

### Hosted Zone Strategy

Domains are managed centrally in the shared services account with subdomain delegation to workload accounts:

```
Shared Services Account ({prefix}-shared)
├── <org_domain> (public)
├── <brand_domain> (public)          ← one per brand, from var.brand_domains
│   ├── dev.<brand_domain>  ─────► delegated to workload account
│   ├── stage.<brand_domain> ───► delegated to workload account
│   └── (apex/prod managed here or delegated)
└── ... (repeated for each brand)
```

## ☸️ Kubernetes (EKS) Architecture

### Cluster Strategy

- **1 EKS cluster per environment account** (e.g., the prod account for a brand has one cluster)
- **Private endpoint only** (no public API server)
- **Managed node groups** or **Karpenter** for scaling

### Per-Cluster Components

```
EKS Cluster
├── Core Add-ons (AWS Managed)
│   ├── vpc-cni
│   ├── coredns
│   └── kube-proxy
├── Platform Add-ons (Helm)
│   ├── AWS Load Balancer Controller
│   ├── external-dns
│   ├── cert-manager
│   ├── karpenter (or cluster-autoscaler)
│   └── external-secrets
├── Observability
│   ├── fluent-bit / OTel Collector
│   ├── prometheus / grafana
│   └── cloudwatch-agent
└── GitOps
    └── Argo CD / Flux
```

## 📊 Cost Considerations

### Two-Tier Provider Model

This project uses two fundamentally different provider models. All providers are **top-level directories** — the categorization is logical, not structural:

```
┌───────────────────────────────────────────────────────────────┐
│              ORG-SCOPED (phase-based 0–6)                    │
│     Parent org owns the organization/account                 │
│     Brands are nested inside (accounts/projects)             │
│                                                              │
│     aws/          ─ Phases 0–6, one AWS Organization         │
│     gcp/          ─ Phases 0–6, one GCP Organization         │
│     digitalocean/ ─ Future IaaS provider                     │
│     linode/       ─ Future IaaS provider                     │
│     hybrid/       ─ Cross-provider glue (future)             │
├───────────────────────────────────────────────────────────────┤
│              BRAND-SCOPED (per-brand stacks)                 │
│     Each brand owns its own tenant/org/workspace             │
│     Parent company is an admin member                        │
│                                                              │
│     github/       ─ Per-brand GitHub orgs                    │
│     railway/      ─ Per-brand Railway workspaces             │
│     supabase/     ─ Per-brand Supabase projects              │
└───────────────────────────────────────────────────────────────┘
```

### Cost Considerations

### What's Free
- AWS Organizations
- Empty AWS accounts
- SCPs and policies

### What Costs Money
- AWS Config (per recorded resource, per rule evaluation)
- CloudTrail (data events, additional trails, S3 storage)
- GuardDuty (per analyzed event)
- Security Hub (per finding, per check)
- EKS ($0.10/hour/cluster)
- NAT Gateways ($0.045/hour + data transfer)
- Load Balancers

### Cost Optimization Tips
1. Start with 1 region, add DR later
2. Use VPC endpoints for ECR/S3 to reduce NAT costs
3. Evaluate AWS Config rules carefully
4. Use Karpenter for efficient node scaling
