# ==============================================================================
# GCP Project Module — Reusable Project Factory
#
# Creates a Google Cloud Project with:
#   - Deterministic project ID (with optional random suffix)
#   - API enablement
#   - Labels
#   - Billing account link
#   - Optional billing budget
#
# Usage:
#   module "project_security" {
#     source          = "../../../gcp/modules/project"
#     name            = "prj-security"
#     folder_id       = google_folder.platform.folder_id
#     billing_account = local.billing_account
#     labels          = { environment = "platform", managed-by = "terraform" }
#     activate_apis   = ["logging.googleapis.com", "monitoring.googleapis.com"]
#   }
# ==============================================================================

resource "random_id" "suffix" {
  count       = var.add_random_suffix ? 1 : 0
  byte_length = 2
}

locals {
  project_id = var.project_id != "" ? var.project_id : (
    var.add_random_suffix
    ? "${var.name}-${random_id.suffix[0].hex}"
    : var.name
  )
}

resource "google_project" "this" {
  name                = var.name
  project_id          = local.project_id
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  auto_create_network = var.auto_create_network
  deletion_policy     = var.deletion_policy

  labels = var.labels
}

resource "google_project_service" "apis" {
  for_each = toset(var.activate_apis)

  project = google_project.this.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}
