terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

# ---------------------------------------------------------------------------
# Zone — create or look up
# ---------------------------------------------------------------------------

resource "cloudflare_zone" "this" {
  count   = var.zone_id == null && var.create_zone ? 1 : 0
  account = { id = var.account_id }
  name    = var.zone_name
  type    = "full"
}

data "cloudflare_zone" "this" {
  count = var.zone_id == null && !var.create_zone ? 1 : 0
  filter = {
    name = var.zone_name
    account = {
      id = var.account_id
    }
  }
}

locals {
  zone_id = (
    var.zone_id != null ? var.zone_id :
    var.create_zone ? cloudflare_zone.this[0].id :
    data.cloudflare_zone.this[0].id
  )
}

# ---------------------------------------------------------------------------
# SSL / TLS zone settings
# ---------------------------------------------------------------------------

resource "cloudflare_zone_setting" "ssl" {
  count      = var.manage_zone_settings ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "ssl"
  value      = var.ssl_mode
}

resource "cloudflare_zone_setting" "min_tls_version" {
  count      = var.manage_zone_settings ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "min_tls_version"
  value      = var.min_tls_version
}

resource "cloudflare_zone_setting" "tls_1_3" {
  count      = var.manage_zone_settings ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "tls_1_3"
  value      = var.tls_1_3 ? "on" : "off"
}

resource "cloudflare_zone_setting" "always_use_https" {
  count      = var.manage_zone_settings ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "always_use_https"
  value      = var.always_use_https ? "on" : "off"
}

resource "cloudflare_zone_setting" "automatic_https_rewrites" {
  count      = var.manage_zone_settings ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "automatic_https_rewrites"
  value      = var.automatic_https_rewrites ? "on" : "off"
}

# Total TLS — Universal SSL on all hostnames, including wildcards
resource "cloudflare_total_tls" "this" {
  count                 = var.manage_zone_settings && var.total_tls_enabled ? 1 : 0
  zone_id               = local.zone_id
  enabled               = true
  certificate_authority = var.total_tls_certificate_authority
}

# ---------------------------------------------------------------------------
# Security zone settings
# ---------------------------------------------------------------------------

resource "cloudflare_zone_setting" "security_level" {
  count      = var.manage_zone_settings ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "security_level"
  value      = var.security_level
}

# ---------------------------------------------------------------------------
# Performance zone settings
# ---------------------------------------------------------------------------

resource "cloudflare_zone_setting" "brotli" {
  count      = var.manage_zone_settings ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "brotli"
  value      = var.brotli ? "on" : "off"
}

resource "cloudflare_zone_setting" "http3" {
  count      = var.manage_zone_settings ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "http3"
  value      = var.http3 ? "on" : "off"
}

resource "cloudflare_zone_setting" "browser_cache_ttl" {
  count      = var.manage_zone_settings ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "browser_cache_ttl"
  value      = var.browser_cache_ttl
}

# ---------------------------------------------------------------------------
# DNSSEC (optional — requires DS record at your domain registrar)
# ---------------------------------------------------------------------------

resource "cloudflare_zone_dnssec" "this" {
  count   = var.manage_zone_settings && var.dnssec_enabled ? 1 : 0
  zone_id = local.zone_id
}

# ---------------------------------------------------------------------------
# DNS records
# ---------------------------------------------------------------------------

resource "cloudflare_dns_record" "this" {
  for_each = var.dns_records

  zone_id  = local.zone_id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  proxied  = each.value.proxied
  ttl      = each.value.proxied ? 1 : each.value.ttl
  priority = each.value.priority
  comment  = each.value.comment
}

# ---------------------------------------------------------------------------
# WAF — Cloudflare Free Managed Ruleset
#
# Cloudflare Managed Ruleset ID (constant, reserved by Cloudflare):
#   efb7b8c949ac4650a09736fc376e9aee
#
# DDoS L7 protection is automatic on all proxied zones; no resource needed.
# This ruleset adds WAF rule inspection on top of the automatic DDoS layer.
# ---------------------------------------------------------------------------

resource "cloudflare_ruleset" "waf_managed" {
  count       = var.manage_zone_settings && var.waf_managed_ruleset_enabled ? 1 : 0
  zone_id     = local.zone_id
  name        = "Cloudflare Managed Rules"
  kind        = "zone"
  phase       = "http_request_firewall_managed"
  description = "Execute Cloudflare Managed WAF ruleset"

  rules = [
    {
      action      = "execute"
      expression  = "true"
      description = "Execute Cloudflare Managed Ruleset"
      action_parameters = {
        id = "efb7b8c949ac4650a09736fc376e9aee"
      }
    }
  ]
}
