# ---------------------------------------------------------------------------
# Auth
# Set via: export TF_VAR_cloudflare_api_token="<token>"
# ---------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token. Set via TF_VAR_cloudflare_api_token env var — never put in tfvars files."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Org / hierarchy identifiers
# Used for bucket naming: <org>-<suborg>-<brand>-<product_suffix>
# ---------------------------------------------------------------------------

variable "org_name" {
  description = "Short org slug used in bucket name prefixes (e.g. acme)"
  type        = string
}

variable "suborg_name" {
  description = "Sub-organisation slug (e.g. core, apps). Leave empty string to omit from names."
  type        = string
  default     = ""
}

variable "brand_name" {
  description = "Brand slug (e.g. myapp, storefront)"
  type        = string
}

variable "environment" {
  description = "Deployment environment: dev | prod (appended to R2 bucket names; zone is shared across envs)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be \"dev\" or \"prod\"."
  }
}

# ---------------------------------------------------------------------------
# Cloudflare account
# ---------------------------------------------------------------------------

variable "account_id" {
  description = "Cloudflare account ID for this org/brand"
  type        = string
}

# ---------------------------------------------------------------------------
# Org remote state — used to resolve zone IDs created by cloudflare/stacks/org
# ---------------------------------------------------------------------------

variable "org_state_bucket" {
  description = "GCS bucket holding the cloudflare/stacks/org Terraform state."
  type        = string
}

# ---------------------------------------------------------------------------
# DNS zones with security settings + DNS records
#
# Key = logical zone label (e.g. "primary", "api").
# Must match the key used in cloudflare/stacks/org zones map so the zone ID
# can be resolved automatically from remote state.
# ---------------------------------------------------------------------------

variable "zones" {
  description = "Map of DNS zones to manage, including security and DNS records."
  type = map(object({
    zone_name            = string
    manage_zone_settings = optional(bool, true)

    # TLS / SSL
    ssl_mode                        = optional(string, "full")
    min_tls_version                 = optional(string, "1.2")
    tls_1_3                         = optional(bool, true)
    always_use_https                = optional(bool, true)
    automatic_https_rewrites        = optional(bool, true)
    total_tls_enabled               = optional(bool, true)
    total_tls_certificate_authority = optional(string, "lets_encrypt")

    # Security
    security_level              = optional(string, "medium")
    waf_managed_ruleset_enabled = optional(bool, true)
    waf_sensitivity_level       = optional(string, "default")

    # Performance
    brotli            = optional(bool, true)
    http3             = optional(bool, true)
    browser_cache_ttl = optional(number, 14400)

    # DNSSEC (requires DS record at your registrar)
    dnssec_enabled = optional(bool, false)

    # DNS records — key = logical label
    dns_records = optional(map(object({
      name     = string
      type     = string
      content  = string
      proxied  = optional(bool, true)
      ttl      = optional(number, 1)
      priority = optional(number, null)
      comment  = optional(string, null)
    })), {})
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# R2 buckets
#
# Key = product suffix used in bucket name: <org>[-<suborg>]-<brand>-<key>
# ---------------------------------------------------------------------------

variable "r2_buckets" {
  description = "Map of R2 buckets. Key becomes part of the bucket name."
  type = map(object({
    location      = optional(string, null)
    storage_class = optional(string, "Standard")
    jurisdiction  = optional(string, "default")

    cors_rules = optional(list(object({
      id              = optional(string, null)
      max_age_seconds = optional(number, 3600)
      expose_headers  = optional(list(string), [])
      allowed = object({
        methods = list(string)
        origins = list(string)
        headers = optional(list(string), [])
      })
    })), [])

    lifecycle_rules = optional(list(object({
      id      = string
      enabled = optional(bool, true)
      prefix  = optional(string, "")

      delete_after_days                            = optional(number, null)
      abort_incomplete_multipart_upload_after_days = optional(number, null)
      transition_to_infrequent_access_after_days   = optional(number, null)
    })), [])

    # Custom domain — set zone_label to reference a zone defined in var.zones
    custom_domain = optional(object({
      domain     = string
      zone_label = string # key in var.zones whose zone_id will be used
      enabled    = optional(bool, true)
      min_tls    = optional(string, "TLSv1.2")
    }), null)
  }))
  default = {}
}
