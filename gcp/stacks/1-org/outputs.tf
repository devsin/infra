# ==============================================================================
# Outputs — consumed by subsequent phases via terraform_remote_state
# ==============================================================================

# --- Folder IDs ---

output "platform_folder_id" {
  description = "Platform folder ID"
  value       = google_folder.platform.folder_id
}

output "workloads_folder_id" {
  description = "Workloads folder ID"
  value       = google_folder.workloads.folder_id
}

output "sandbox_folder_id" {
  description = "Sandbox folder ID (empty if disabled)"
  value       = var.enable_sandbox ? google_folder.sandbox[0].folder_id : ""
}

output "brand_folder_ids" {
  description = "Map of brand name → folder ID"
  value       = { for k, v in google_folder.brand : k => v.folder_id }
}

# --- All folder IDs (convenience map) ---

output "folder_ids" {
  description = "Map of all folder names to their IDs"
  value = merge(
    {
      platform  = google_folder.platform.folder_id
      workloads = google_folder.workloads.folder_id
    },
    var.enable_sandbox ? { sandbox = google_folder.sandbox[0].folder_id } : {},
    { for k, v in google_folder.brand : k => v.folder_id },
  )
}

# --- Platform Project IDs (commented out) ---

# output "security_project_id" {
#   description = "Security platform project ID"
#   value       = module.project_security.project_id
# }

# output "log_project_id" {
#   description = "Logging platform project ID"
#   value       = module.project_log.project_id
# }

# output "shared_project_id" {
#   description = "Shared services platform project ID"
#   value       = module.project_shared.project_id
# }

# output "sandbox_project_id" {
#   description = "Sandbox project ID (empty if disabled)"
#   value       = var.enable_sandbox ? module.project_sandbox[0].project_id : ""
# }

# output "platform_project_ids" {
#   description = "Map of platform project purpose → project ID"
#   value = {
#     security = module.project_security.project_id
#     log      = module.project_log.project_id
#     shared   = module.project_shared.project_id
#   }
# }

# --- Brand Project IDs ---

output "brand_project_ids" {
  description = "Map of brand-env → project ID"
  value       = { for k, v in module.project_brand_env : k => v.project_id }
}

# --- Common Config (passthrough for downstream phases) ---

output "common_config" {
  description = "Common configuration inherited from Phase 0 + Phase 1 additions"
  value = {
    org_id              = local.org_id
    billing_account     = local.billing_account
    default_region      = local.default_region
    folder_prefix       = local.folder_prefix
    project_prefix      = local.project_prefix
    platform_folder_id  = google_folder.platform.folder_id
    workloads_folder_id = google_folder.workloads.folder_id
    # security_project_id = module.project_security.project_id
    # log_project_id      = module.project_log.project_id
    # shared_project_id   = module.project_shared.project_id
  }
}
