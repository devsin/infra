# ==============================================================================
# Backend Configuration — Terraform State in GCS
#
# Uses the seed project's GCS bucket created in Phase 0.
# Fill in actual values from Phase 0 outputs:
#   terraform -chdir=../0-bootstrap output seed_state_bucket_name
# ==============================================================================

terraform {
  backend "gcs" {
    bucket = "REDACTED" # → Phase 0: seed_state_bucket_name
    prefix = "terraform/org"
  }
}
