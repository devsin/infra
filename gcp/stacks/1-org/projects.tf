# ==============================================================================
# Projects — Platform + Brand × Environment
#
# Platform projects live under the Platform folder.
# Brand projects are created dynamically per brand×env under brand folders.
# Uses the reusable gcp/modules/project module.
# ==============================================================================

# ------------------------------------------------------------------------------
# Platform Projects
# ------------------------------------------------------------------------------

module "project_security" {
  source = "../../modules/project"

  name            = "${local.project_prefix}-p-security"
  folder_id       = google_folder.platform.folder_id
  billing_account = local.billing_account
  deletion_policy = var.project_deletion_policy
  activate_apis   = var.platform_apis

  labels = {
    environment = "platform"
    purpose     = "security"
    managed-by  = "terraform"
  }
}

module "project_log" {
  source = "../../modules/project"

  name            = "${local.project_prefix}-p-log"
  folder_id       = google_folder.platform.folder_id
  billing_account = local.billing_account
  deletion_policy = var.project_deletion_policy

  activate_apis = concat(var.platform_apis, [
    "bigquery.googleapis.com",
  ])

  labels = {
    environment = "platform"
    purpose     = "logging"
    managed-by  = "terraform"
  }
}

module "project_shared" {
  source = "../../modules/project"

  name            = "${local.project_prefix}-p-shared"
  folder_id       = google_folder.platform.folder_id
  billing_account = local.billing_account
  deletion_policy = var.project_deletion_policy

  activate_apis = concat(var.platform_apis, [
    "dns.googleapis.com",
    "certificatemanager.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  labels = {
    environment = "platform"
    purpose     = "shared-services"
    managed-by  = "terraform"
  }
}

# ------------------------------------------------------------------------------
# Sandbox Project (optional)
# ------------------------------------------------------------------------------

module "project_sandbox" {
  source = "../../modules/project"
  count  = var.enable_sandbox ? 1 : 0

  name            = "${local.project_prefix}-sandbox"
  folder_id       = google_folder.sandbox[0].folder_id
  billing_account = local.billing_account
  deletion_policy = "DELETE" # sandbox can be destroyed
  activate_apis   = var.workload_apis

  labels = {
    environment = "sandbox"
    managed-by  = "terraform"
  }
}

# ------------------------------------------------------------------------------
# Brand × Environment Projects (dynamic)
# ------------------------------------------------------------------------------

locals {
  brand_env_pairs = flatten([
    for b in var.brands : [
      for e in b.envs : {
        key   = "${b.name}-${e}"
        brand = b.name
        env   = e
      }
    ]
  ])
}

module "project_brand_env" {
  source   = "../../modules/project"
  for_each = { for pair in local.brand_env_pairs : pair.key => pair }

  name            = "${local.project_prefix}-${each.key}"
  folder_id       = google_folder.brand[each.value.brand].folder_id
  billing_account = local.billing_account
  deletion_policy = var.project_deletion_policy
  activate_apis   = var.workload_apis

  labels = {
    brand       = each.value.brand
    environment = each.value.env
    managed-by  = "terraform"
  }
}
