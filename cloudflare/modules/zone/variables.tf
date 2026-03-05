variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "zone_name" {
  description = "DNS zone / domain name (e.g. example.com)"
  type        = string
}

variable "zone_id" {
  description = "Existing zone ID to use directly. When set, skips both zone creation and zone lookup — use this to make an environment standalone without depending on another stack's state."
  type        = string
  default     = null
}

variable "create_zone" {
  description = "true = create zone; false = look up an existing zone (ignored when zone_id is set)"
  type        = bool
  default     = true
}

variable "manage_zone_settings" {
  description = "Whether to manage zone-level settings (TLS, WAF, security, performance). Set false on non-owning envs (e.g. dev) to avoid state conflicts when prod already owns the zone settings."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# SSL / TLS
# ---------------------------------------------------------------------------

variable "ssl_mode" {
  description = "SSL mode: off | flexible | full | strict"
  type        = string
  default     = "full"
}

variable "min_tls_version" {
  description = "Minimum TLS version: 1.0 | 1.1 | 1.2 | 1.3"
  type        = string
  default     = "1.2"
}

variable "tls_1_3" {
  description = "Enable TLS 1.3"
  type        = bool
  default     = true
}

variable "always_use_https" {
  description = "Redirect all HTTP requests to HTTPS"
  type        = bool
  default     = true
}

variable "automatic_https_rewrites" {
  description = "Rewrite http:// links in HTML to https://"
  type        = bool
  default     = true
}

variable "total_tls_enabled" {
  description = "Enable Total TLS (Universal SSL for all hostnames)"
  type        = bool
  default     = true
}

variable "total_tls_certificate_authority" {
  description = "CA for Total TLS: lets_encrypt | google"
  type        = string
  default     = "lets_encrypt"
}

# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------

variable "security_level" {
  description = "Zone security level: off | essentially_off | low | medium | high | under_attack"
  type        = string
  default     = "medium"
}

variable "waf_managed_ruleset_enabled" {
  description = "Deploy the Cloudflare Managed WAF ruleset (free plan supported)"
  type        = bool
  default     = true
}

variable "waf_sensitivity_level" {
  description = "WAF managed ruleset sensitivity: default | medium | low | eoff"
  type        = string
  default     = "default"
}

# ---------------------------------------------------------------------------
# Performance
# ---------------------------------------------------------------------------

variable "brotli" {
  description = "Enable Brotli compression"
  type        = bool
  default     = true
}

variable "http3" {
  description = "Enable HTTP/3 (QUIC)"
  type        = bool
  default     = true
}

variable "browser_cache_ttl" {
  description = "Browser cache TTL in seconds (0 = respect origin headers)"
  type        = number
  default     = 14400
}

# ---------------------------------------------------------------------------
# DNSSEC
# ---------------------------------------------------------------------------

variable "dnssec_enabled" {
  description = "Enable DNSSEC. Requires DS record to be added at your registrar."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# DNS records
# ---------------------------------------------------------------------------

variable "dns_records" {
  description = "Map of DNS records. Key = logical label."
  type = map(object({
    name     = string
    type     = string
    content  = string
    proxied  = optional(bool, true)
    ttl      = optional(number, 1)
    priority = optional(number, null)
    comment  = optional(string, null)
  }))
  default = {}
}
