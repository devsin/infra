# ==============================================================================
# GCP Bootstrap — Remote Backend (GCS)
#
# State is stored in the seed project's GCS bucket.
# After the bucket is created on the first local apply, re-init with:
#
#   tofu init -reconfigure \
#     -backend-config="bucket=<seed-state-bucket>" \
#     -backend-config="prefix=terraform/gcp/bootstrap"
#
# Get the bucket name from Phase 0 output:
#   tofu output seed_state_bucket_name
# ==============================================================================

terraform {
  backend "gcs" {
  }
}
