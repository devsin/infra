# ==============================================================================
# Backend — GCS (empty; pass bucket + prefix at init time)
#
# Usage:
#   tofu init \
#     -backend-config="bucket=<gcs-tfstate-bucket>" \
#     -backend-config="prefix=terraform/cloudflare/org/<org>"
# ==============================================================================

terraform {
  backend "gcs" {}
}
