# Phase 4: Platform (GCP)

## 🎯 Objective

Provision shared platform services per brand/environment using the **proj service account**
(`sa-tf-proj`) from Phase 0:
- Artifact Registry (equivalent to AWS ECR)
- Cloud KMS keys
- GCS buckets (artifacts, backups)
- Secret Manager
- Monitoring & alerting baseline

## 🔐 Authentication

```hcl
provider "google" {
  impersonate_service_account = data.terraform_remote_state.bootstrap.outputs.proj_sa_email
  region = var.default_region
}

terraform {
  backend "gcs" {
    bucket = "bkt-prj-b-seed-XXXX-tfstate"  # from Phase 0 output
    prefix = "terraform/platform"            # + brand/env via -backend-config
  }
}
```

## 📋 What Gets Created

| Resource | Purpose | GCP Equivalent of |
|----------|---------|-------------------|
| Artifact Registry | Container images | ECR |
| Cloud KMS | Encryption keys | KMS |
| GCS Buckets | Artifacts & backups | S3 |
| Secret Manager | Secrets storage | Secrets Manager |
| Monitoring | Dashboards & alerts | CloudWatch |

## 📝 Stack Pattern

Same flat pattern as Phase 3:

```
gcp/stacks/4-platform/
├── main.tf
├── variables.tf
├── outputs.tf
├── backend.tf
└── envs/
    ├── brand-a-dev.tfvars
    └── brand-a-prod.tfvars
```

## 📝 Key Resources

```hcl
# Artifact Registry (Docker)
resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.primary_region
  repository_id = "${var.prefix}-${var.brand}-${var.env}"
  format        = "DOCKER"

  labels = {
    brand       = var.brand
    environment = var.env
  }
}

# KMS for workload encryption
resource "google_kms_key_ring" "workload" {
  name     = "${var.prefix}-${var.brand}-${var.env}"
  project  = var.project_id
  location = var.primary_region
}

resource "google_kms_crypto_key" "workload" {
  name            = "general"
  key_ring        = google_kms_key_ring.workload.id
  rotation_period = "7776000s" # 90 days
}

# Secret Manager
resource "google_secret_manager_secret" "example" {
  project   = var.project_id
  secret_id = "${var.prefix}-${var.brand}-${var.env}-app-secrets"

  replication {
    auto {}
  }

  labels = {
    brand       = var.brand
    environment = var.env
  }
}
```

## 🔑 GCP vs AWS Platform Comparison

| Feature | AWS | GCP |
|---------|-----|-----|
| Container registry | ECR | Artifact Registry |
| Encryption | KMS | Cloud KMS |
| Object storage | S3 | GCS |
| Secrets | Secrets Manager | Secret Manager |
| Monitoring | CloudWatch | Cloud Monitoring |
| Alerting | CloudWatch Alarms + SNS | Cloud Monitoring Alerts |

## ✅ Phase 4 Checklist

- [ ] Artifact Registry created per brand/env
- [ ] KMS key rings and keys provisioned
- [ ] GCS buckets for artifacts and backups
- [ ] Secret Manager configured
- [ ] Monitoring dashboards baseline
- [ ] Alert policies configured
