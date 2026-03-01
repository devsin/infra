# ==============================================================================
# Outputs — values needed by Phase 1B, Phase 2, and all subsequent phases
# ==============================================================================

# --- Organization ---

output "organization_id" {
  description = "The Organization ID"
  value       = aws_organizations_organization.org.id
}

output "organization_arn" {
  description = "The Organization ARN"
  value       = aws_organizations_organization.org.arn
}

output "root_id" {
  description = "The Organization root ID"
  value       = aws_organizations_organization.org.roots[0].id
}

output "management_account_id" {
  description = "The management account ID"
  value       = aws_organizations_organization.org.master_account_id
}

# --- OUs ---

output "ou_ids" {
  description = "Map of OU paths to IDs"
  value = {
    for path, ou in local.all_ous : path => ou.id
  }
}

# --- Accounts ---

output "account_ids" {
  description = "Map of account names to account IDs"
  value       = local.account_ids
}

output "accounts" {
  description = "Full account details (name → {id, arn, email})"
  value = {
    for name, account in aws_organizations_account.accounts : name => {
      id    = account.id
      arn   = account.arn
      email = account.email
    }
  }
  sensitive = true
}

output "sandbox_account_id" {
  description = "Sandbox account ID (if created)"
  value       = var.enable_sandbox ? aws_organizations_account.sandbox[0].id : null
}

# --- Core account IDs (convenience) ---

output "security_account_id" {
  description = "Security account ID"
  value       = aws_organizations_account.accounts["${var.prefix}-security"].id
}

output "log_account_id" {
  description = "Log archive account ID"
  value       = aws_organizations_account.accounts["${var.prefix}-log"].id
}

output "shared_account_id" {
  description = "Shared services account ID"
  value       = aws_organizations_account.accounts["${var.prefix}-shared"].id
}

# --- SCPs ---

output "scp_ids" {
  description = "Map of SCP names to IDs"
  value = {
    deny_leave_org     = aws_organizations_policy.deny_leave_org.id
    deny_root_user     = aws_organizations_policy.deny_root_user.id
    block_public_s3    = aws_organizations_policy.block_public_s3.id
    region_restriction = aws_organizations_policy.region_restriction.id
  }
}
