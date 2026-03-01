# ==============================================================================
# Phase 1: Organization (GCP)
#
# Creates the GCP org structure using SA impersonation (sa-tf-org from Phase 0):
#   1. Folder hierarchy (Platform, Workloads, Sandbox)
#   2. Platform projects (security, log, shared)
#   3. Dynamic brand folders + brand×env projects
#   4. Organization policies (org-policies.tf)
#
# Architecture:
#   Organization (or parent_folder)
#   ├── {folder_prefix}-bootstrap/          ← Phase 0
#   ├── {folder_prefix}-platform/
#   │   ├── {project_prefix}-p-security     (project)
#   │   ├── {project_prefix}-p-log          (project)
#   │   └── {project_prefix}-p-shared       (project)
#   ├── {folder_prefix}-workloads/
#   │   ├── {folder_prefix}-{brand}/        (folder per brand)
#   │   │   ├── {project_prefix}-{brand}-dev    (project)
#   │   │   ├── {project_prefix}-{brand}-stage  (project)
#   │   │   └── {project_prefix}-{brand}-prod   (project)
#   │   └── ...more brands (dynamic)
#   └── {folder_prefix}-sandbox/            (optional)
#       └── {project_prefix}-sandbox        (project)
#
# Deployment:
#   1. Update backend.tf bucket with Phase 0 seed_state_bucket_name
#   2. Populate terraform.tfvars (see terraform.tfvars.example)
#   3. terraform init
#   4. terraform plan
#   5. terraform apply
# ==============================================================================

# ------------------------------------------------------------------------------
# Remote State — read Phase 0 outputs
# ------------------------------------------------------------------------------

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "terraform/bootstrap"
  }
}

# ------------------------------------------------------------------------------
# Locals — derived from bootstrap outputs
# ------------------------------------------------------------------------------

locals {
  org_id          = data.terraform_remote_state.bootstrap.outputs.common_config.org_id
  billing_account = data.terraform_remote_state.bootstrap.outputs.common_config.billing_account
  parent          = data.terraform_remote_state.bootstrap.outputs.common_config.parent_id
  folder_prefix   = data.terraform_remote_state.bootstrap.outputs.common_config.folder_prefix
  project_prefix  = data.terraform_remote_state.bootstrap.outputs.common_config.project_prefix
  default_region  = data.terraform_remote_state.bootstrap.outputs.common_config.default_region
}

# ------------------------------------------------------------------------------
# Folder Hierarchy — Top Level
# ------------------------------------------------------------------------------

resource "google_folder" "platform" {
  display_name        = "${local.folder_prefix}-platform"
  parent              = local.parent
  deletion_protection = var.folder_deletion_protection
}

resource "google_folder" "workloads" {
  display_name        = "${local.folder_prefix}-workloads"
  parent              = local.parent
  deletion_protection = var.folder_deletion_protection
}

resource "google_folder" "sandbox" {
  count = var.enable_sandbox ? 1 : 0

  display_name        = "${local.folder_prefix}-sandbox"
  parent              = local.parent
  deletion_protection = var.folder_deletion_protection
}

# ------------------------------------------------------------------------------
# Brand Folders — dynamic, one per brand under Workloads
# ------------------------------------------------------------------------------

resource "google_folder" "brand" {
  for_each = { for b in var.brands : b.name => b }

  display_name        = "${local.folder_prefix}-${each.key}"
  parent              = google_folder.workloads.name
  deletion_protection = var.folder_deletion_protection
}
