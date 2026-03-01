# ==============================================================================
# Backend Configuration — Terraform State in GCS
#
# Uses the seed project's GCS bucket created in GCP Phase 0.
# ==============================================================================

terraform {
  backend "gcs" {
    bucket = "REDACTED"
    prefix = "terraform/github/org"
  }
}
