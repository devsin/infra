# ==============================================================================
# Backend Configuration — Terraform State in S3
#
# IMPORTANT: This file should be commented out on the very first `terraform apply`
# because the S3 bucket doesn't exist yet (chicken-and-egg problem).
#
# Steps:
#   1. Comment out this entire file
#   2. Run: terraform init && terraform apply   (creates the bucket with local state)
#   3. Uncomment this file
#   4. Update the bucket/dynamodb_table values with your actual outputs
#   5. Run: terraform init -migrate-state       (migrates local → S3)
#   6. Verify: terraform plan                   (should show no changes)
#   7. Delete the local terraform.tfstate file
# ==============================================================================

# terraform {
#   backend "s3" {
#     bucket         = "REPLACE-terraform-state-ACCOUNT_ID"  # → terraform output state_bucket_name
#     key            = "bootstrap/terraform.tfstate"
#     region         = "eu-west-1"                            # → your primary_region
#     encrypt        = true
#     dynamodb_table = "REPLACE-terraform-lock"               # → terraform output lock_table_name
#   }
# }
