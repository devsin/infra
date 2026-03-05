locals {
  # Base prefix without environment — used as a label for zones and outputs
  name_prefix = var.suborg_name != "" ? "${var.org_name}-${var.suborg_name}-${var.brand_name}" : "${var.org_name}-${var.brand_name}"

  # Bucket prefix includes environment: <org>[-<suborg>]-<brand>-<env>
  # Example: acme-myapp-dev  or  acme-core-myapp-prod
  bucket_prefix = "${local.name_prefix}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Org remote state — zone IDs created by cloudflare/stacks/org
# ---------------------------------------------------------------------------

data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = var.org_state_bucket
    prefix = "terraform/cloudflare/org/${var.org_name}"
  }
}

# ---------------------------------------------------------------------------
# DNS zones — one module instance per zone
# Includes: TLS settings, security level, WAF managed ruleset, DNS records,
#           Total TLS, DNSSEC, Brotli, HTTP/3
#
# Free tier features enabled by default:
#   - DDoS L7 protection: automatic on all proxied records (no resource needed)
#   - WAF Managed Ruleset: Cloudflare Free Managed Rules
#   - Universal SSL / Total TLS
#   - Always-Use-HTTPS redirect
#   - TLS 1.2 minimum, TLS 1.3
#   - Brotli compression, HTTP/3 (QUIC)
# ---------------------------------------------------------------------------

module "zone" {
  source   = "../../modules/zone"
  for_each = var.zones

  account_id           = var.account_id
  zone_name            = each.value.zone_name
  zone_id              = data.terraform_remote_state.org.outputs.zone_ids[each.key]
  create_zone          = false
  manage_zone_settings = each.value.manage_zone_settings

  ssl_mode                        = each.value.ssl_mode
  min_tls_version                 = each.value.min_tls_version
  tls_1_3                         = each.value.tls_1_3
  always_use_https                = each.value.always_use_https
  automatic_https_rewrites        = each.value.automatic_https_rewrites
  total_tls_enabled               = each.value.total_tls_enabled
  total_tls_certificate_authority = each.value.total_tls_certificate_authority

  security_level              = each.value.security_level
  waf_managed_ruleset_enabled = each.value.waf_managed_ruleset_enabled
  waf_sensitivity_level       = each.value.waf_sensitivity_level

  brotli            = each.value.brotli
  http3             = each.value.http3
  browser_cache_ttl = each.value.browser_cache_ttl

  dnssec_enabled = each.value.dnssec_enabled
  dns_records    = each.value.dns_records
}

# ---------------------------------------------------------------------------
# R2 buckets
#
# Bucket name = "<name_prefix>-<env>-<key>"
# Example: "acme-myapp-prod-avatars" or "acme-core-myapp-prod-uploads"
# ---------------------------------------------------------------------------

module "r2_bucket" {
  source   = "../../modules/r2-bucket"
  for_each = var.r2_buckets

  account_id    = var.account_id
  bucket_name   = "${local.bucket_prefix}-${each.key}"
  location      = each.value.location
  storage_class = each.value.storage_class
  jurisdiction  = each.value.jurisdiction

  cors_rules      = each.value.cors_rules
  lifecycle_rules = each.value.lifecycle_rules

  # Resolve the zone_label reference into an actual zone_id from the zone module
  custom_domain = each.value.custom_domain != null ? {
    domain  = each.value.custom_domain.domain
    zone_id = module.zone[each.value.custom_domain.zone_label].zone_id
    enabled = each.value.custom_domain.enabled
    min_tls = each.value.custom_domain.min_tls
  } : null
}
