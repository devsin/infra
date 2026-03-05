output "zone_ids" {
  description = "Map of zone label => Cloudflare zone ID. Consumed by brand stacks via terraform_remote_state."
  value       = { for k, z in cloudflare_zone.this : k => z.id }
}

output "zone_names" {
  description = "Map of zone label => domain name."
  value       = { for k, z in cloudflare_zone.this : k => z.name }
}

output "name_servers" {
  description = "Map of zone label => Cloudflare nameservers. Update these at your registrar after first apply."
  value       = { for k, z in cloudflare_zone.this : k => z.name_servers }
}
