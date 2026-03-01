# ==============================================================================
# Outputs — needed by all subsequent GCP phases
#
# Following the terraform-example-foundation pattern:
#   - common_config: shared configuration for remote_state data sources
#   - Per-phase SA emails for impersonation
#   - State bucket + WIF details for CI/CD
# ==============================================================================

# --- Common Configuration (consumed by all subsequent phases via remote_state) ---

output "common_config" {
  description = "Common configuration data for subsequent phases"
  value = {
    org_id                = var.org_id
    org_name              = var.org_name
    org_domain            = var.org_domain
    billing_account       = var.billing_account
    default_region        = var.default_region
    project_prefix        = var.project_prefix
    folder_prefix         = var.folder_prefix
    parent_folder         = var.parent_folder
    parent_id             = local.parent
    bootstrap_folder_id   = google_folder.bootstrap.folder_id
    bootstrap_folder_name = google_folder.bootstrap.name
  }
}

# --- Projects ---

output "seed_project_id" {
  description = "Seed project ID (holds state bucket and service accounts)"
  value       = google_project.seed.project_id
}

output "cicd_project_id" {
  description = "CI/CD project ID (holds WIF for GitHub Actions)"
  value       = google_project.cicd.project_id
}

# --- State Bucket ---

output "seed_state_bucket_name" {
  description = "GCS bucket name for Terraform state"
  value       = google_storage_bucket.tfstate.name
}

output "seed_state_bucket_url" {
  description = "GCS bucket self-link"
  value       = google_storage_bucket.tfstate.url
}

# --- KMS ---

output "kms_key_ring_id" {
  description = "KMS key ring ID"
  value       = google_kms_key_ring.tfstate.id
}

output "kms_crypto_key_id" {
  description = "KMS crypto key ID"
  value       = google_kms_crypto_key.tfstate.id
}

# --- Service Account Emails (per phase) ---

output "bootstrap_sa_email" {
  description = "Bootstrap phase Terraform service account email"
  value       = google_service_account.terraform_sa["bootstrap"].email
}

output "org_sa_email" {
  description = "Organization phase Terraform service account email"
  value       = google_service_account.terraform_sa["org"].email
}

output "env_sa_email" {
  description = "Environment phase Terraform service account email"
  value       = google_service_account.terraform_sa["env"].email
}

output "net_sa_email" {
  description = "Network phase Terraform service account email"
  value       = google_service_account.terraform_sa["net"].email
}

output "proj_sa_email" {
  description = "Projects phase Terraform service account email"
  value       = google_service_account.terraform_sa["proj"].email
}

# --- Workload Identity Federation ---

output "wif_pool_name" {
  description = "Workload Identity Pool full resource name"
  value       = google_iam_workload_identity_pool.github.name
}

output "wif_provider_name" {
  description = "Workload Identity Provider full resource name"
  value       = google_iam_workload_identity_pool_provider.github.name
}

# --- Bootstrap Folder ---

output "bootstrap_folder_id" {
  description = "Bootstrap folder ID"
  value       = google_folder.bootstrap.folder_id
}
