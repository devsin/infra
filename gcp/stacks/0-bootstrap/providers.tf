# ==============================================================================
# Provider Configuration
#
# No default project — projects are created by this stack.
# All resources specify project explicitly.
# ==============================================================================

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
