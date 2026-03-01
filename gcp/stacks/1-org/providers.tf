# ==============================================================================
# Provider Configuration — SA Impersonation
#
# Uses the org service account (sa-tf-org) created in Phase 0.
# No human credentials needed after bootstrap.
# ==============================================================================

provider "google" {
  impersonate_service_account = data.terraform_remote_state.bootstrap.outputs.org_sa_email
  region                      = var.default_region

  default_labels = {
    managed-by = "terraform"
    phase      = "1-org"
  }
}

provider "google-beta" {
  impersonate_service_account = data.terraform_remote_state.bootstrap.outputs.org_sa_email
  region                      = var.default_region

  default_labels = {
    managed-by = "terraform"
    phase      = "1-org"
  }
}
