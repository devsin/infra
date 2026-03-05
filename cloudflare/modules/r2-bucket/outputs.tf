output "bucket_name" {
  description = "The R2 bucket name"
  value       = cloudflare_r2_bucket.this.name
}

output "bucket_location" {
  description = "The resolved bucket location"
  value       = cloudflare_r2_bucket.this.location
}

output "custom_domain" {
  description = "Custom domain attached to this bucket (null if not configured)"
  value       = var.custom_domain != null ? cloudflare_r2_custom_domain.this[0].domain : null
}
