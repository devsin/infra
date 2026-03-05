# ==============================================================================
# Railway Brand Stack — Remote Backend (GCS)
#
# State is stored in the same GCS bucket as GCP stacks, under a separate prefix.
# Init with:
#   tofu init -reconfigure -backend-config="bucket=<state-bucket>" \
#             -backend-config="prefix=terraform/railway/<brand>"
# ==============================================================================

terraform {
  backend "gcs" {
  }
}
