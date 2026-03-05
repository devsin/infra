# Partial backend — provide bucket + prefix at init time:
#
#   tofu init \
#     -backend-config="bucket=<tfstate-bucket>" \
#     -backend-config="prefix=terraform/cloudflare/<brand>-<env>"
#
# To switch brands / envs:
#   tofu init -reconfigure \
#     -backend-config="bucket=<tfstate-bucket>" \
#     -backend-config="prefix=terraform/cloudflare/<other-brand>-<env>"

terraform {
  backend "gcs" {
  }
}
