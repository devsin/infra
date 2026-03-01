# Organizational Hierarchy

This document covers the **hierarchy structures** for org-scoped cloud providers — AWS OUs (Organizational Units) and GCP Folders. Both follow the same brand-driven pattern.

> Brand sub-units under `Workloads` are created dynamically from `brands.yaml`.

---

## AWS: OU Structure

### Complete OU Tree

```
Root
│
├─── Platform
│    │
│    ├─── Security
│    │    ├── {prefix}-security     (Security tooling, delegated admin)
│    │    └── {prefix}-log          (Central log archive)
│    │
│    └─── SharedServices
│         └── {prefix}-shared       (DNS, CI/CD, artifacts)
│
├─── Workloads
│    │
│    ├─── <Brand>                   (one OU per brand, dynamically created)
│    │    ├── {prefix}-<brand>-dev
│    │    ├── {prefix}-<brand>-stage
│    │    └── {prefix}-<brand>-prod
│    │
│    └─── ... (more brands — auto-created from var.brands)
│
└─── Sandbox
     └── {prefix}-sandbox            (Optional: experimentation)

Note: {prefix}-mgmt stays in Root (management account)
```

### AWS OU Paths (Terraform Reference)

| OU Path | Purpose | Accounts |
|---------|---------|----------|
| `Platform` | Company infrastructure | — |
| `Platform/Security` | Security & logging | `{prefix}-security`, `{prefix}-log` |
| `Platform/SharedServices` | Shared services | `{prefix}-shared` |
| `Workloads` | All brand workloads | — |
| `Workloads/{Brand}` | Per-brand OU (one per brand) | `{prefix}-{brand}-{dev,stage,prod}` |
| `Sandbox` | Experimentation | `{prefix}-sandbox` |

## 🎯 Hierarchy Design Rationale

### Why This Structure?

1. **Platform vs Workloads separation**
   - Clear boundary between "company infrastructure" and "product environments"
   - Different SCP policies for each

2. **Security OU under Platform**
   - Groups security-critical accounts
   - Tighter controls, limited human access
   - Easier to apply strict SCPs

3. **Brand-level OUs under Workloads**
   - Apply brand-specific policies if needed
   - Clear ownership boundaries
   - Cost allocation by brand

4. **Environment accounts under Brand**
   - All envs for one brand grouped together
   - Can apply dev-specific relaxations at brand level if needed

### Alternative Structures (Not Recommended)

❌ **Environment-first** (`Workloads/Dev/{Brand}`):
- Harder to manage brand-specific policies
- Less intuitive ownership model

❌ **Flat structure** (all accounts under Workloads):
- No granularity for SCP application
- Harder to scale

> These rationale points apply equally to GCP folder design.

---

## GCP: Folder Structure

### Complete Folder Tree

```
Organization ({org_domain})
│
├─── {fldr}-bootstrap
│    ├── {prj}-b-seed            (State, KMS, 5 service accounts)
│    └── {prj}-b-cicd-gh         (WIF pool for GitHub Actions)
│
├─── {fldr}-platform
│    ├── {prj}-security          (SCC, org-level security)
│    ├── {prj}-log               (Central log sink)
│    └── {prj}-shared            (Artifact Registry, DNS, KMS)
│
├─── {fldr}-workloads
│    │
│    ├─── <Brand>                (one folder per brand, dynamically created)
│    │    ├── {prj}-<brand>-dev
│    │    ├── {prj}-<brand>-stage
│    │    └── {prj}-<brand>-prod
│    │
│    └─── ... (more brands — auto-created from brands.yaml)
│
└─── {fldr}-sandbox
     └── {prj}-sandbox            (Optional: experimentation)

Note: {fldr} = folder_prefix, {prj} = project_prefix
```

### GCP Folder Paths (Terraform Reference)

| Folder Path | Purpose | Projects |
|-------------|---------|----------|
| `{fldr}-bootstrap` | Bootstrap infrastructure | `{prj}-b-seed`, `{prj}-b-cicd-gh` |
| `{fldr}-platform` | Company-wide services | `{prj}-security`, `{prj}-log`, `{prj}-shared` |
| `{fldr}-workloads` | All brand workloads | — |
| `{fldr}-workloads/{Brand}` | Per-brand folder | `{prj}-{brand}-{dev,stage,prod}` |
| `{fldr}-sandbox` | Experimentation | `{prj}-sandbox` |

### GCP Folder → Org Policy Mapping

| Folder | Org Policies | Notes |
|--------|-------------|-------|
| Organization root | `constraints/iam.allowedPolicyMemberDomains` | Only org domain members |
| `{fldr}-bootstrap` | Minimal restrictions | Seed SA needs broad access |
| `{fldr}-platform` | `constraints/compute.requireShieldedVm`, `constraints/storage.uniformBucketLevelAccess` | Security controls |
| `{fldr}-workloads` | Domain restriction, uniform bucket access, shielded VM | Base for all workloads |
| `{fldr}-workloads/{Brand}` | (inherits) | Can add brand-specific policies |
| `{fldr}-sandbox` | Domain restriction + budget constraints | Cost controls |

### GCP Folder Terraform Definition

```hcl
# Folder structure via google_folder resources
resource "google_folder" "bootstrap" {
  display_name = "${var.folder_prefix}-bootstrap"
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "platform" {
  display_name = "${var.folder_prefix}-platform"
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "workloads" {
  display_name = "${var.folder_prefix}-workloads"
  parent       = "organizations/${var.org_id}"
}

# Dynamic brand folders
resource "google_folder" "brand" {
  for_each     = { for b in var.brands : b.name => b }
  display_name = title(each.key)
  parent       = google_folder.workloads.id
}

resource "google_folder" "sandbox" {
  display_name = "${var.folder_prefix}-sandbox"
  parent       = "organizations/${var.org_id}"
}
```

---

## Cross-Cloud Equivalents

| Concept | AWS | GCP |
|---------|-----|-----|
| Top-level hierarchy | OU (Organizational Unit) | Folder |
| Sub-unit | Nested OU | Nested Folder |
| Isolation unit inside | Account | Project |
| Policy attached to hierarchy | SCP (Service Control Policy) | Org Policy Constraint |
| Root node | Organization root (management acct) | Organization node |
| Dynamic brand grouping | `Workloads/{Brand}` OU | `{fldr}-workloads/{Brand}` folder |
| Platform grouping | `Platform/Security`, `Platform/SharedServices` | `{fldr}-bootstrap`, `{fldr}-platform` |

> The main structural difference: GCP has a dedicated **bootstrap folder** for seed/CICD projects
> (created in Phase 0), while AWS uses the management account for bootstrap resources.

## 📋 AWS OU Terraform Definition

```hcl
# variables.tf

variable "brands" {
  description = "List of brand definitions"
  type = list(object({
    name   = string
    domain = string
    envs   = list(string)
  }))
}

# locals.tf — build OU structure dynamically from brands

locals {
  # Static OUs (always present)
  static_ous = [
    { name = "Platform",       path = "Platform",                parent_path = "" },
    { name = "Workloads",      path = "Workloads",               parent_path = "" },
    { name = "Sandbox",        path = "Sandbox",                 parent_path = "" },
    { name = "Security",       path = "Platform/Security",       parent_path = "Platform" },
    { name = "SharedServices", path = "Platform/SharedServices", parent_path = "Platform" },
  ]

  # Dynamic brand OUs (one per brand)
  brand_ous = [
    for brand in var.brands : {
      name        = title(brand.name)
      path        = "Workloads/${title(brand.name)}"
      parent_path = "Workloads"
    }
  ]

  ou_structure = concat(local.static_ous, local.brand_ous)
}
```

## 🔗 AWS OU → SCP Mapping

| OU | SCPs Attached | Notes |
|----|---------------|-------|
| Root | `FullAWSAccess` (default) | Only default policy |
| Platform | — | Inherits from Root |
| Platform/Security | `DenyLeaveOrg`, `DenyRootUser`, `ProtectLogging` | Strictest controls |
| Platform/SharedServices | `DenyLeaveOrg`, `DenyRootUser`, `BlockPublicS3` | |
| Workloads | `DenyLeaveOrg`, `DenyRootUser`, `BlockPublicS3`, `ProtectLogging` | Base for all workloads |
| Workloads/{Brand} | (inherits) | Can add brand-specific later |
| Sandbox | `DenyLeaveOrg`, `DenyRootUser`, `BlockPublicS3`, `RegionRestriction` | Stricter cost controls |

## 🚀 Creation Order

### AWS OUs

OUs must be created in dependency order:

```
1. Root (exists)
2. Platform, Workloads, Sandbox (Level 1)
3. Platform/Security, Platform/SharedServices (Level 2 under Platform)
4. Workloads/<Brand>, ... (Level 2 under Workloads — one per brand, dynamic)
```

### GCP Folders

```
1. Organization node (exists)
2. {fldr}-bootstrap, {fldr}-platform, {fldr}-workloads, {fldr}-sandbox (Level 1)
3. Brand folders under {fldr}-workloads (Level 2 — one per brand, dynamic)
```

## 📈 Scaling the Hierarchy

### Adding a New Brand

1. Add entry to `var.brands`:
   ```hcl
   {
     name   = "new-brand"
     domain = "newbrand.com"
     envs   = ["dev", "stage", "prod"]
   }
   ```

2. Run `terraform apply` — the OU (AWS) and folder (GCP) and accounts/projects are created automatically.

### Adding Environment Types

If you need additional environments (e.g., `qa`, `perf`):

1. Add the env to the brand's `envs` list: `["dev", "qa", "stage", "prod"]`
2. Accounts are placed in the same brand OU
3. Consider adding environment-specific SCPs if needed

### Adding a Network Hub Account

If adopting TGW (Transit Gateway) hub/spoke:

```
Platform
├── Security
├── SharedServices
└── Network          ← New OU
    └── {prefix}-network
```

GCP equivalent: add a `{prj}-network` project under `{fldr}-platform` (or create a `{fldr}-network` folder).
