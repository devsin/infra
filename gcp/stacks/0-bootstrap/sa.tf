# ==============================================================================
# Granular Service Accounts — one per foundation phase
#
# Following the terraform-example-foundation pattern of least-privilege SAs:
#   - sa-tf-bootstrap : Bootstrap phase (this stack)
#   - sa-tf-org       : Organization structure (Phase 1)
#   - sa-tf-env       : Environments (Phase 2)
#   - sa-tf-net       : Networking (Phase 3)
#   - sa-tf-proj      : Projects / Workloads (Phase 4+)
#
# Each SA gets specific IAM roles at the org, folder, seed-project,
# and billing-account levels.
# ==============================================================================

locals {
  granular_sa = {
    "bootstrap" = "Foundation Bootstrap SA"
    "org"       = "Foundation Organization SA"
    "env"       = "Foundation Environment SA"
    "net"       = "Foundation Network SA"
    "proj"      = "Foundation Projects SA"
  }

  # Org-level roles per phase SA
  granular_sa_org_level_roles = {
    "bootstrap" = [
      "roles/resourcemanager.organizationAdmin",
      "roles/serviceusage.serviceUsageConsumer",
      "roles/browser",
    ]
    "org" = [
      "roles/orgpolicy.policyAdmin",
      "roles/logging.configWriter",
      "roles/resourcemanager.organizationAdmin",
      "roles/resourcemanager.organizationViewer",
      "roles/resourcemanager.folderCreator",
      "roles/resourcemanager.projectCreator",
      "roles/accesscontextmanager.policyAdmin",
      "roles/essentialcontacts.admin",
      "roles/resourcemanager.tagAdmin",
      "roles/resourcemanager.tagUser",
      "roles/securitycenter.sourcesEditor",
      "roles/browser",
    ]
    "env" = [
      "roles/resourcemanager.tagUser",
      "roles/browser",
    ]
    "net" = [
      "roles/accesscontextmanager.policyAdmin",
      "roles/compute.xpnAdmin",
      "roles/browser",
    ]
    "proj" = [
      "roles/accesscontextmanager.policyAdmin",
      "roles/resourcemanager.organizationAdmin",
      "roles/serviceusage.serviceUsageConsumer",
      "roles/browser",
    ]
  }

  # Folder-level roles (bootstrap folder is the parent for now)
  granular_sa_folder_level_roles = {
    "bootstrap" = ["roles/resourcemanager.folderAdmin"]
    "org"       = ["roles/resourcemanager.folderAdmin"]
    "env"       = ["roles/resourcemanager.folderAdmin"]
    "net" = [
      "roles/resourcemanager.folderViewer",
      "roles/compute.networkAdmin",
      "roles/compute.securityAdmin",
      "roles/dns.admin",
    ]
    "proj" = [
      "roles/resourcemanager.folderAdmin",
      "roles/compute.networkAdmin",
      "roles/compute.xpnAdmin",
    ]
  }

  # Seed project roles
  granular_sa_seed_project_roles = {
    "bootstrap" = [
      "roles/storage.admin",
      "roles/iam.serviceAccountAdmin",
      "roles/resourcemanager.projectDeleter",
      "roles/cloudkms.admin",
      "roles/serviceusage.serviceUsageAdmin",
    ]
    "org"  = ["roles/storage.objectAdmin"]
    "env"  = ["roles/storage.objectAdmin"]
    "net"  = ["roles/storage.objectAdmin"]
    "proj" = ["roles/storage.objectAdmin", "roles/storage.admin"]
  }
}

# ------------------------------------------------------------------------------
# Service Accounts (created in seed project)
# ------------------------------------------------------------------------------

resource "google_service_account" "terraform_sa" {
  for_each = local.granular_sa

  project      = google_project.seed.project_id
  account_id   = "sa-tf-${each.key}"
  display_name = each.value
  description  = "${each.value}. Managed by Terraform."

  depends_on = [google_project_service.seed_apis]
}

# Enable self-impersonation (needed when GitHub Actions impersonates → then SA
# calls other APIs using its own token)
resource "google_service_account_iam_member" "self_impersonate" {
  for_each = local.granular_sa

  service_account_id = google_service_account.terraform_sa[each.key].id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.terraform_sa[each.key].email}"
}

# ------------------------------------------------------------------------------
# Org-Level IAM Bindings
# ------------------------------------------------------------------------------

resource "google_organization_iam_member" "sa_org_roles" {
  for_each = {
    for pair in flatten([
      for sa_key, roles in local.granular_sa_org_level_roles : [
        for role in roles : {
          key  = "${sa_key}.${role}"
          sa   = sa_key
          role = role
        }
      ]
    ]) : pair.key => pair
  }

  org_id = var.org_id
  role   = each.value.role
  member = "serviceAccount:${google_service_account.terraform_sa[each.value.sa].email}"
}

# ------------------------------------------------------------------------------
# Folder-Level IAM Bindings (on the org or parent_folder)
# ------------------------------------------------------------------------------

resource "google_folder_iam_member" "sa_folder_roles" {
  for_each = {
    for pair in flatten([
      for sa_key, roles in local.granular_sa_folder_level_roles : [
        for role in roles : {
          key  = "${sa_key}.${role}"
          sa   = sa_key
          role = role
        }
      ]
    ]) : pair.key => pair
  }

  folder = google_folder.bootstrap.id
  role   = each.value.role
  member = "serviceAccount:${google_service_account.terraform_sa[each.value.sa].email}"
}

# ------------------------------------------------------------------------------
# Seed Project IAM Bindings
# ------------------------------------------------------------------------------

resource "google_project_iam_member" "sa_seed_project_roles" {
  for_each = {
    for pair in flatten([
      for sa_key, roles in local.granular_sa_seed_project_roles : [
        for role in roles : {
          key  = "${sa_key}.${role}"
          sa   = sa_key
          role = role
        }
      ]
    ]) : pair.key => pair
  }

  project = google_project.seed.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.terraform_sa[each.value.sa].email}"
}

# ------------------------------------------------------------------------------
# Billing Account IAM
#   - All SAs get billing.user (link projects to billing)
#   - Only bootstrap SA gets billing.admin (manage billing settings)
# ------------------------------------------------------------------------------

resource "google_billing_account_iam_member" "sa_billing_user" {
  for_each = local.granular_sa

  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.terraform_sa[each.key].email}"
}

resource "google_billing_account_iam_member" "sa_billing_admin" {
  billing_account_id = var.billing_account
  role               = "roles/billing.admin"
  member             = "serviceAccount:${google_service_account.terraform_sa["bootstrap"].email}"
}
