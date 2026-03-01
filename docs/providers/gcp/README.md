# GCP Phases — README

## 📋 Phase Overview

| Phase | Name | SA Used | Scope | Dependencies | Destroyable |
|-------|------|---------|-------|--------------|-------------|
| 0 | Bootstrap | User (ADC) | Global | None | Partially |
| 1 | Organization | `sa-tf-org` | Global | Phase 0 | Partially* |
| 1B | IAM Baseline | `sa-tf-org` | Per-Project | Phase 1 | Yes |
| 2 | Security | `sa-tf-env` | Global | Phase 1 | Yes |
| 3 | Networking | `sa-tf-net` | Per-Project/Region | Phase 2 | Yes |
| 4 | Platform | `sa-tf-proj` | Per-Project/Region | Phase 3 | Yes |
| 5 | GKE | `sa-tf-proj` | Per-Project/Region | Phase 4 | Yes |
| 6 | Workloads | `sa-tf-proj` | Per-Cluster | Phase 5 | Yes (GitOps) |

\* Projects can be deleted but have a 30-day recovery window.

> All service accounts are created in Phase 0 (seed project) following the
> [terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation)
> pattern. Each phase impersonates its designated SA via Workload Identity Federation.

## 🔄 Apply/Destroy Order

### Apply Order (Top → Bottom)
```
Phase 0 → Phase 1 → Phase 1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
```

### Destroy Order (Bottom → Top)
```
Phase 6 → Phase 5 → Phase 4 → Phase 3 → Phase 2 → Phase 1B → Phase 1 → Phase 0
```

## 📚 Phase Documentation

| Phase | Document | Status |
|-------|----------|--------|
| Phase 0 | [Bootstrap](./PHASE-0-BOOTSTRAP.md) | ✅ Implemented |
| Phase 1 | [Organization](./PHASE-1-ORGANIZATION.md) | 📄 Documented |
| Phase 1B | [IAM Baseline](./PHASE-1B-IAM-BASELINE.md) | 📄 Documented |
| Phase 2 | [Security](./PHASE-2-SECURITY.md) | 📄 Documented |
| Phase 3 | [Networking](./PHASE-3-NETWORKING.md) | 📄 Documented |
| Phase 4 | [Platform](./PHASE-4-PLATFORM.md) | 📄 Documented |
| Phase 5 | [GKE](./PHASE-5-GKE.md) | 📄 Documented |
| Phase 6 | [Workloads](./PHASE-6-WORKLOADS.md) | 📄 Documented |

## 📁 Stack Structure

Each phase has its own Terraform "stack" (root module) with isolated state.
Stack directories use the `N-name` naming convention (e.g. `0-bootstrap`, `1-org`).

**Phase 0** runs with user credentials (ADC). **Phases 1–6** impersonate the
appropriate Phase 0 service account. **Phases 0–2** are global stacks (applied once).
**Phases 3–5** are per-brand/env stacks driven by `.tfvars` files:

```
gcp/stacks/
├── 0-bootstrap/
│   ├── main.tf           # Folder, seed project, KMS, state bucket
│   ├── sa.tf             # 5 granular SAs + IAM bindings
│   ├── cicd.tf           # CI/CD project, WIF pool + provider
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── versions.tf
│   ├── backend.tf
│   └── terraform.tfvars
│
├── 1-org/
│   └── ...
│
├── 1b-iam-baseline/
│   └── ...
│
├── 2-security/
│   └── ...
│
├── 3-networking/
│   ├── *.tf
│   └── envs/
│       ├── brand-a-dev.tfvars
│       └── brand-a-prod.tfvars
│
├── 4-platform/
│   └── ... (same flat pattern)
│
└── 5-gke/
    └── ... (same flat pattern)
```

## 🔐 State Management

All phases store state in the seed project's GCS bucket (created in Phase 0).
Each phase uses a separate state prefix:

| Phase | State Prefix | How Set |
|-------|-------------|---------|
| Phase 0 | `terraform/bootstrap` | Hardcoded in `backend.tf` |
| Phase 1 | `terraform/org` | Hardcoded in `backend.tf` |
| Phase 1B | `terraform/iam-baseline` | Hardcoded in `backend.tf` |
| Phase 2 | `terraform/security` | Hardcoded in `backend.tf` |
| Phase 3 | `terraform/networking/<brand>/<env>/<region>` | `-backend-config="prefix=..."` |
| Phase 4 | `terraform/platform/<brand>/<env>/<region>` | `-backend-config="prefix=..."` |
| Phase 5 | `terraform/gke/<brand>/<env>/<region>` | `-backend-config="prefix=..."` |
| Phase 6 | N/A (GitOps) | Argo CD manages state |

## 🔑 Service Account → Phase Mapping

```
Phase 0 (Bootstrap)
  └── Creates: sa-tf-bootstrap, sa-tf-org, sa-tf-env, sa-tf-net, sa-tf-proj
       │
       ├── sa-tf-org ──────► Phase 1 (Organization) + Phase 1B (IAM Baseline)
       ├── sa-tf-env ──────► Phase 2 (Security)
       ├── sa-tf-net ──────► Phase 3 (Networking)
       └── sa-tf-proj ─────► Phase 4 (Platform) + Phase 5 (GKE) + Phase 6 (Workloads)
```

Each SA authenticates via:
1. **GitHub Actions** → WIF OIDC → impersonate SA
2. **Local development** → `gcloud auth application-default login` → impersonate SA
