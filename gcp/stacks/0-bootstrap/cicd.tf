# ==============================================================================
# CI/CD Project — Workload Identity Federation for GitHub Actions
#
# Separation of concerns (following terraform-example-foundation):
#   - Seed project  → state storage + service accounts
#   - CI/CD project → authentication infrastructure (WIF)
#
# GitHub Actions authenticates via OIDC → WIF → impersonates the
# appropriate phase service account from sa.tf
# ==============================================================================

# ------------------------------------------------------------------------------
# CI/CD Project
# ------------------------------------------------------------------------------

resource "google_project" "cicd" {
  name                = "${var.project_prefix}-b-cicd-gh"
  project_id          = "${var.project_prefix}-b-cicd-gh-${random_id.cicd_suffix.hex}"
  folder_id           = google_folder.bootstrap.folder_id
  billing_account     = var.billing_account
  deletion_policy     = var.project_deletion_policy
  auto_create_network = false

  labels = {
    application_name = "cicd-github"
    environment      = "bootstrap"
  }
}

resource "random_id" "cicd_suffix" {
  byte_length = 2
}

# Enable required APIs on CI/CD project
locals {
  cicd_apis = [
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
  ]
}

resource "google_project_service" "cicd_apis" {
  for_each = toset(local.cicd_apis)

  project = google_project.cicd.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# ------------------------------------------------------------------------------
# Workload Identity Pool + Provider — GitHub Actions OIDC
# ------------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.cicd.project_id
  workload_identity_pool_id = "${var.prefix}-foundation-pool"
  display_name              = "Foundation GitHub Actions Pool"
  description               = "WIF pool for GitHub Actions CI/CD pipelines"

  depends_on = [google_project_service.cicd_apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.cicd.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.prefix}-gh-provider"
  display_name                       = "GitHub OIDC Provider"

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

# ------------------------------------------------------------------------------
# WIF → Service Account Mapping
#
# Each phase SA can be impersonated by GitHub Actions running from
# the configured repository.
# ------------------------------------------------------------------------------

resource "google_service_account_iam_member" "wif_sa_binding" {
  for_each = local.granular_sa

  service_account_id = google_service_account.terraform_sa[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${var.github_repo}"
}

# ------------------------------------------------------------------------------
# Bootstrap SA also needs IAM admin on CI/CD project
# (to manage WIF resources in future updates)
# ------------------------------------------------------------------------------

resource "google_project_iam_member" "bootstrap_cicd_iam" {
  project = google_project.cicd.project_id
  role    = "roles/iam.workloadIdentityPoolAdmin"
  member  = "serviceAccount:${google_service_account.terraform_sa["bootstrap"].email}"
}
