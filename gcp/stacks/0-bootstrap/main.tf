# ==============================================================================
# Phase 0: Bootstrap (GCP) — Foundation Pattern
#
# Inspired by terraform-google-modules/terraform-example-foundation
#
# Creates:
#   1. Bootstrap folder under the org (or parent_folder)
#   2. Seed project — state bucket, KMS, granular service accounts
#   3. CI/CD project — Workload Identity Federation for GitHub Actions
#
# Architecture:
#   [org or parent_folder]
#   └── {folder_prefix}-bootstrap/
#       ├── {project_prefix}-b-seed      (state, KMS, SAs)
#       └── {project_prefix}-b-cicd-gh   (WIF pool/provider)
#
# Manual prereqs: only org + billing account
#
# Deployment:
#   1. gcloud auth application-default login
#   2. terraform init
#   3. terraform plan
#   4. terraform apply
#   5. Uncomment backend.tf → terraform init -migrate-state
# ==============================================================================

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------

locals {
  parent = var.parent_folder != "" ? "folders/${var.parent_folder}" : "organizations/${var.org_id}"
}

# ------------------------------------------------------------------------------
# Bootstrap Folder
# ------------------------------------------------------------------------------

resource "google_folder" "bootstrap" {
  display_name        = "${var.folder_prefix}-bootstrap"
  parent              = local.parent
  deletion_protection = var.folder_deletion_protection
}

# ------------------------------------------------------------------------------
# Seed Project — holds Terraform state + service accounts
# ------------------------------------------------------------------------------

resource "google_project" "seed" {
  name                = "${var.project_prefix}-b-seed"
  project_id          = "${var.project_prefix}-b-seed-${random_id.seed_suffix.hex}"
  folder_id           = google_folder.bootstrap.folder_id
  billing_account     = var.billing_account
  deletion_policy     = var.project_deletion_policy
  auto_create_network = false

  labels = {
    application_name = "seed-bootstrap"
    environment      = "bootstrap"
  }
}

resource "random_id" "seed_suffix" {
  byte_length = 2
}

# Enable required APIs on seed project
locals {
  seed_apis = [
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "cloudasset.googleapis.com",
  ]
}

resource "google_project_service" "seed_apis" {
  for_each = toset(local.seed_apis)

  project = google_project.seed.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# ------------------------------------------------------------------------------
# Cloud KMS — State Encryption
# ------------------------------------------------------------------------------

resource "google_kms_key_ring" "tfstate" {
  name     = "${var.prefix}-keyring"
  project  = google_project.seed.project_id
  location = var.default_region

  depends_on = [google_project_service.seed_apis]
}

resource "google_kms_crypto_key" "tfstate" {
  name            = "${var.prefix}-key"
  key_ring        = google_kms_key_ring.tfstate.id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# Grant GCS service agent permission to use the KMS key
data "google_storage_project_service_account" "seed_gcs" {
  project = google_project.seed.project_id

  depends_on = [google_project_service.seed_apis]
}

resource "google_kms_crypto_key_iam_member" "gcs_encrypt" {
  crypto_key_id = google_kms_crypto_key.tfstate.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.seed_gcs.email_address}"
}

# ------------------------------------------------------------------------------
# GCS Bucket — Terraform State
# ------------------------------------------------------------------------------

resource "google_storage_bucket" "tfstate" {
  name          = "${var.bucket_prefix}-${google_project.seed.project_id}-tfstate"
  project       = google_project.seed.project_id
  location      = var.default_region
  force_destroy = var.bucket_force_destroy

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.tfstate.id
  }

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    name = "${var.prefix}-tfstate"
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_encrypt]
}
