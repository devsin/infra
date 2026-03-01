# ==============================================================================
# Backend Configuration — Terraform State in GCS
#
# After the seed project and GCS bucket are created, uncomment and fill
# in the actual values from terraform output:
#
#   terraform output seed_state_bucket_name
# ==============================================================================

terraform {
  backend "gcs" {
    bucket = "REDACTED"
    prefix = "terraform/bootstrap"
  }
}
