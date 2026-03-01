provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Company     = var.org_name
      ManagedBy   = "terraform"
      Environment = "management"
      Phase       = "1-org"
    }
  }
}
