output "zone_ids" {
  description = "Map of zone label → Cloudflare zone ID"
  value       = { for k, v in module.zone : k => v.zone_id }
}

output "zone_name_servers" {
  description = "Map of zone label → Cloudflare nameservers (point your registrar here for new zones)"
  value       = { for k, v in module.zone : k => v.name_servers }
}

output "zone_dnssec_ds_records" {
  description = "Map of zone label → DS record (add at registrar when dnssec_enabled = true)"
  value       = { for k, v in module.zone : k => v.dnssec_ds_record }
}

output "r2_bucket_names" {
  description = "Map of bucket key → actual R2 bucket name"
  value       = { for k, v in module.r2_bucket : k => v.bucket_name }
}

output "r2_bucket_custom_domains" {
  description = "Map of bucket key → custom domain (null if not configured)"
  value       = { for k, v in module.r2_bucket : k => v.custom_domain }
}

output "name_prefix" {
  description = "Base name prefix for this brand (org[-suborg]-brand)"
  value       = local.name_prefix
}

output "bucket_prefix" {
  description = "Name prefix used for all R2 buckets: <name_prefix>-<environment>"
  value       = local.bucket_prefix
}

output "environment" {
  description = "Active environment (dev | prod)"
  value       = var.environment
}
