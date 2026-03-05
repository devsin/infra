# ==============================================================================
# Railway Brand Stack — Versions & Providers
#
# Uses the community Railway Terraform provider.
# ==============================================================================

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "~> 0.6"
    }
  }
}
