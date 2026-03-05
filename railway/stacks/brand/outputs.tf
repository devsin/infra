# ==============================================================================
# Railway Brand Stack — Outputs
# ==============================================================================

output "project_id" {
  description = "Railway project ID"
  value       = railway_project.this.id
}

output "environment_ids" {
  description = "Map of environment name → ID"
  value       = local.environment_ids
}

output "service_ids" {
  description = "Map of service name → ID"
  value       = { for k, v in railway_service.this : k => v.id }
}

output "custom_domains" {
  description = "Map of domain key → DNS record value (for CNAME setup)"
  value = {
    for k, v in railway_custom_domain.this : k => {
      domain           = v.domain
      dns_record_value = v.dns_record_value
      host_label       = v.host_label
      zone             = v.zone
    }
  }
}
