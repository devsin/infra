# Phase 0: Bootstrap (GCP)

## 🎯 Objective

Set up the foundational infrastructure for all subsequent GCP phases, following the
[terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation)
pattern. This phase creates everything needed to run Terraform in CI/CD with
least-privilege service accounts.

**What this phase creates:**

- A **bootstrap folder** under the organization (or an optional parent folder)
- A **seed project** — Terraform state bucket, Cloud KMS, granular service accounts
- A **CI/CD project** — Workload Identity Federation for GitHub Actions
- **5 granular service accounts** — one per subsequent foundation phase

## 📋 What Gets Created

### Architecture

```
Organization (or parent_folder)
└── {folder_prefix}-bootstrap/
    ├── {project_prefix}-b-seed-XXXX        (Terraform state, KMS, SAs)
    └── {project_prefix}-b-cicd-gh-XXXX     (WIF pool + OIDC provider)
```

### Resource Inventory

| Resource | Purpose | Location |
|----------|---------|----------|
| `google_folder.bootstrap` | Contains all bootstrap projects | Org root / parent folder |
| `google_project.seed` | Terraform state + service accounts | Bootstrap folder |
| `google_project.cicd` | WIF authentication infra | Bootstrap folder |
| `google_storage_bucket.tfstate` | KMS-encrypted state bucket | Seed project |
| `google_kms_key_ring` + `crypto_key` | State encryption (90-day rotation) | Seed project |
| 5 × `google_service_account` | Per-phase Terraform SAs | Seed project |
| `google_iam_workload_identity_pool` | GitHub Actions auth pool | CI/CD project |
| `google_iam_workload_identity_pool_provider` | OIDC provider | CI/CD project |

### Service Accounts

| SA | ID | Used By |
|----|----|---------|
| Bootstrap | `sa-tf-bootstrap` | Phase 0 (this stack) |
| Organization | `sa-tf-org` | Phase 1 (folders, projects, org policies) |
| Environment | `sa-tf-env` | Phase 2 (security, environments) |
| Network | `sa-tf-net` | Phase 3 (VPC, NAT, DNS) |
| Projects | `sa-tf-proj` | Phase 4+ (platform, workloads) |

Each SA has org-level, folder-level, seed-project, and billing IAM bindings
following the principle of least privilege. Self-impersonation is enabled for
token exchange via WIF.

> **Note:** Unlike AWS, GCP doesn't need a separate lock table — GCS has built-in object locking.

## 🏗️ Prerequisites

**Manual steps (one-time only):**

1. **GCP Organization** — created via Google Workspace or Cloud Identity
2. **Billing Account** — linked to the organization
3. **gcloud CLI** — installed and authenticated
4. **Terraform** — version >= 1.10.0

That's it. Everything else is created by Terraform.

## 🔐 Authentication Setup

### Authenticate with gcloud

```bash
gcloud auth login
gcloud auth application-default login
```

No need to set a default project — this stack creates its own projects.

## 📁 Stack Structure

```
gcp/stacks/0-bootstrap/
├── versions.tf              # Terraform & provider version constraints
├── providers.tf             # Google + Google-beta providers (no default project)
├── backend.tf               # GCS backend (commented out initially)
├── variables.tf             # Input variables (required + optional)
├── main.tf                  # Bootstrap folder, seed project, KMS, state bucket
├── sa.tf                    # 5 granular service accounts + IAM bindings
├── cicd.tf                  # CI/CD project, WIF pool + provider, SA bindings
├── outputs.tf               # Outputs for all subsequent phases
├── terraform.tfvars         # Your values (gitignored)
└── terraform.tfvars.example # Example values
```

## 📝 Terraform Configuration

### versions.tf

```hcl
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
```

### providers.tf

```hcl
provider "google" {
  region = var.default_region

  default_labels = {
    managed-by  = "terraform"
    environment = "bootstrap"
    phase       = "0-bootstrap"
  }
}

provider "google-beta" {
  region = var.default_region

  default_labels = {
    managed-by  = "terraform"
    environment = "bootstrap"
    phase       = "0-bootstrap"
  }
}
```

> No `project` set on the providers — projects are created by this stack and specified explicitly on each resource.

### variables.tf — Required

| Variable | Description | Example |
|----------|-------------|---------|
| `org_id` | GCP Organization ID (numeric) | `"123456789012"` |
| `billing_account` | Billing Account ID | `"012345-6789AB-CDEF01"` |
| `org_name` | Organization display name | `"mycompany"` |
| `org_domain` | Organization domain | `"mycompany.com"` |
| `github_owner` | GitHub org or user | `"my-github-org"` |
| `github_repo` | Infrastructure repo name | `"infra"` |
| `prefix` | Short prefix for resources (2-9 chars) | `"mc"` |

### variables.tf — Optional (with defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `project_prefix` | `"prj"` | Prefix for project IDs |
| `folder_prefix` | `"fldr"` | Prefix for folder names |
| `bucket_prefix` | `"bkt"` | Prefix for GCS buckets |
| `default_region` | `"europe-west1"` | Default region |
| `bucket_force_destroy` | `false` | Allow deleting state bucket with objects |
| `kms_prevent_destroy` | `true` | Prevent KMS key destruction |
| `folder_deletion_protection` | `true` | Prevent folder deletion |
| `project_deletion_policy` | `"PREVENT"` | Project deletion policy |
| `parent_folder` | `""` | Optional parent folder ID (empty = org root) |

### main.tf — Key Resources

```hcl
# Bootstrap folder
resource "google_folder" "bootstrap" {
  display_name        = "${var.folder_prefix}-bootstrap"
  parent              = local.parent  # org or parent_folder
  deletion_protection = var.folder_deletion_protection
}

# Seed project (random suffix for globally unique ID)
resource "google_project" "seed" {
  name            = "${var.project_prefix}-b-seed"
  project_id      = "${var.project_prefix}-b-seed-${random_id.seed_suffix.hex}"
  folder_id       = google_folder.bootstrap.folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
}

# KMS key ring + key (90-day rotation)
resource "google_kms_key_ring" "tfstate" { ... }
resource "google_kms_crypto_key" "tfstate" { ... }

# GCS state bucket — encrypted, versioned, uniform access
resource "google_storage_bucket" "tfstate" {
  name          = "${var.bucket_prefix}-${google_project.seed.project_id}-tfstate"
  project       = google_project.seed.project_id
  location      = var.default_region
  force_destroy = var.bucket_force_destroy

  versioning { enabled = true }
  encryption { default_kms_key_name = google_kms_crypto_key.tfstate.id }
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition { num_newer_versions = 5 }
    action    { type = "Delete" }
  }
}
```

### sa.tf — Granular Service Accounts

5 service accounts are created in the seed project, each with specific IAM bindings:

| SA | Org-Level Roles | Folder Roles | Seed Project Roles |
|----|----------------|--------------|-------------------|
| `sa-tf-bootstrap` | orgAdmin, serviceUsageConsumer, browser | folderAdmin | storage.admin, iam.saAdmin, kms.admin |
| `sa-tf-org` | orgPolicy.policyAdmin, logging.configWriter, orgAdmin, tagAdmin, ... | folderAdmin | storage.objectAdmin |
| `sa-tf-env` | tagUser, browser | folderAdmin | storage.objectAdmin |
| `sa-tf-net` | accesscontextmanager.policyAdmin, compute.xpnAdmin, browser | folderViewer, compute.networkAdmin, dns.admin | storage.objectAdmin |
| `sa-tf-proj` | orgAdmin, accesscontextmanager.policyAdmin, serviceUsageConsumer, browser | folderAdmin, compute.networkAdmin, compute.xpnAdmin | storage.objectAdmin, storage.admin |

All SAs also receive `roles/billing.user` and `roles/billing.admin` on the billing account.

### cicd.tf — Workload Identity Federation

```hcl
# CI/CD project
resource "google_project" "cicd" {
  name       = "${var.project_prefix}-b-cicd-gh"
  project_id = "${var.project_prefix}-b-cicd-gh-${random_id.cicd_suffix.hex}"
  folder_id  = google_folder.bootstrap.folder_id
  ...
}

# WIF Pool + OIDC Provider
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${var.prefix}-foundation-pool"
  ...
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_provider_id = "${var.prefix}-gh-provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_owner}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# All 5 SAs can be impersonated via WIF from the configured repo
resource "google_service_account_iam_member" "wif_sa_binding" {
  for_each           = local.granular_sa
  service_account_id = google_service_account.terraform_sa[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/.../attribute.repository/..."
}
```

### outputs.tf — Key Outputs

| Output | Description |
|--------|-------------|
| `common_config` | Map with org_id, domain, billing, region, prefixes, parent, bootstrap folder |
| `seed_project_id` | Seed project ID |
| `cicd_project_id` | CI/CD project ID |
| `seed_state_bucket_name` | GCS state bucket name |
| `kms_key_ring_id` / `kms_crypto_key_id` | KMS resource IDs |
| `bootstrap_sa_email` | Bootstrap SA email |
| `org_sa_email` | Organization SA email |
| `env_sa_email` | Environment SA email |
| `net_sa_email` | Network SA email |
| `proj_sa_email` | Projects SA email |
| `wif_pool_name` / `wif_provider_name` | WIF resource names |
| `bootstrap_folder_id` | Bootstrap folder ID |

### backend.tf (commented out initially)

```hcl
# terraform {
#   backend "gcs" {
#     bucket = "REPLACE-with-seed-state-bucket"  # → terraform output seed_state_bucket_name
#     prefix = "terraform/bootstrap"
#   }
# }
```

## 🚀 Deployment Steps

### Step 1: Configure Variables

```bash
cd gcp/stacks/0-bootstrap

# Copy the example and fill in your values
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
org_id          = "123456789012"
billing_account = "012345-6789AB-CDEF01"
org_name        = "mycompany"
org_domain      = "mycompany.com"
github_owner    = "my-github-org"
github_repo     = "infra"
prefix          = "mc"
```

### Step 2: Initialize & Apply

```bash
# Authenticate
gcloud auth application-default login

# Initialize (local state for first run)
terraform init

# Review the plan
terraform plan

# Apply
terraform apply
```

### Step 3: Migrate State to GCS

After apply, get the bucket name and uncomment `backend.tf`:

```bash
# Get the bucket name
terraform output seed_state_bucket_name

# Edit backend.tf — uncomment and fill in the bucket name
```

```hcl
terraform {
  backend "gcs" {
    bucket = "bkt-prj-b-seed-XXXX-tfstate"   # ← from output
    prefix = "terraform/bootstrap"
  }
}
```

Then migrate:
```bash
terraform init -migrate-state
terraform plan   # Should show no changes
```

### Step 4: Configure GitHub Actions (Optional)

After apply, get the WIF details for GitHub Actions:

```bash
terraform output wif_pool_name
terraform output wif_provider_name
terraform output bootstrap_sa_email
```

Use these in your GitHub Actions workflow:
```yaml
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.BOOTSTRAP_SA_EMAIL }}
```

## 🔑 How Subsequent Phases Use Bootstrap

Each subsequent phase:
1. Reads the bootstrap state via `terraform_remote_state`
2. Configures its provider to impersonate the appropriate SA
3. Uses the GCS bucket for its own state (different prefix)

Example for Phase 1:
```hcl
# Phase 1 providers.tf
provider "google" {
  impersonate_service_account = data.terraform_remote_state.bootstrap.outputs.org_sa_email
}

# Phase 1 backend.tf
terraform {
  backend "gcs" {
    bucket = "bkt-prj-b-seed-XXXX-tfstate"
    prefix = "terraform/org"
  }
}
```

## ⚠️ Important Notes

### Foundation Pattern vs Simple Bootstrap

This stack follows Google's [terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation) pattern:

| Aspect | Simple (old) | Foundation (current) |
|--------|-------------|---------------------|
| Projects | 1 management project | 2 projects (seed + cicd) |
| Service accounts | 1 broad SA | 5 granular SAs (per phase) |
| Folders | None | Bootstrap folder |
| CI/CD auth | Single WIF binding | WIF → per-phase SA impersonation |
| Permissions | `roles/editor` (broad) | Least-privilege per SA |

### Security Notes

1. **No broad `roles/editor`** — each SA only gets the roles it needs
2. **WIF attribute condition** restricts access to your GitHub organization
3. **KMS encryption** for state at rest with automatic 90-day key rotation
4. **Versioned state bucket** with lifecycle rules (keep 5 versions)
5. **Self-impersonation** enabled for token exchange flows

### GCS vs S3 Differences

| Feature | AWS (S3) | GCP (GCS) |
|---------|----------|-----------|
| State storage | S3 bucket | GCS bucket |
| Locking | DynamoDB table (separate) | Built-in GCS locking |
| Encryption | KMS key + bucket config | Cloud KMS key + bucket config |
| CI/CD auth | OIDC → IAM Role | WIF → SA impersonation |
| Identity separation | Single role | 5 granular SAs |

## ✅ Phase 0 Checklist

- [ ] Bootstrap folder created under org (or parent folder)
- [ ] Seed project created with required APIs enabled
- [ ] CI/CD project created with required APIs enabled
- [ ] Cloud KMS key ring and key created (90-day rotation)
- [ ] GCS state bucket created with encryption and versioning
- [ ] 5 granular service accounts created with appropriate IAM bindings
- [ ] WIF pool and OIDC provider configured for GitHub Actions
- [ ] All SAs bound to WIF for GitHub impersonation
- [ ] State migrated from local to GCS
- [ ] Outputs verified for subsequent phases
