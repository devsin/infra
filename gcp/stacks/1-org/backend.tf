# ==============================================================================
# GCP Organization — Remote Backend (GCS)
#
# State is stored in the same seed GCS bucket created in Phase 0.
# Init with:
#   tofu init -reconfigure \
#     -backend-config="bucket=<seed-state-bucket>" \
#     -backend-config="prefix=terraform/gcp/org"
#
# Get the bucket name from Phase 0 output:
#   tofu -chdir=../0-bootstrap output seed_state_bucket_name
# ==============================================================================

terraform {
  backend "gcs" {
  }
}
