# ==============================================================================
# Backend Configuration — Terraform State in S3
#
# Replace the bucket, region, and dynamodb_table values with your actual
# Phase 0 outputs:
#
#   cd ../phase-0-bootstrap
#   terraform output state_bucket_name
#   terraform output lock_table_name
# ==============================================================================

terraform {
  backend "s3" {
    bucket         = "REPLACE-terraform-state-ACCOUNT_ID" # → terraform output state_bucket_name
    key            = "org/terraform.tfstate"
    region         = "eu-west-1" # → your primary_region
    encrypt        = true
    dynamodb_table = "REPLACE-terraform-lock" # → terraform output lock_table_name
  }
}
