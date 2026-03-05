output "zone_id" {
  description = "Cloudflare zone ID"
  value       = local.zone_id
}

output "zone_name" {
  description = "Zone domain name"
  value       = var.zone_name
}

output "name_servers" {
  description = "Cloudflare nameservers to delegate to (only relevant when create_zone = true)"
  value       = var.create_zone ? cloudflare_zone.this[0].name_servers : null
}

output "dns_record_ids" {
  description = "Map of DNS record label → record ID"
  value       = { for k, v in cloudflare_dns_record.this : k => v.id }
}

output "dnssec_ds_record" {
  description = "DS record value to add at your registrar (only when dnssec_enabled = true)"
  value       = var.dnssec_enabled ? cloudflare_zone_dnssec.this[0].ds : null
  sensitive   = false
}
