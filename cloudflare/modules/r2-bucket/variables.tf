variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "bucket_name" {
  description = "R2 bucket name (globally unique within account)"
  type        = string
}

variable "location" {
  description = "Bucket location hint: apac | eeur | enam | weur | wnam | oc. Leave null for automatic."
  type        = string
  default     = null
}

variable "storage_class" {
  description = "Storage class: Standard | InfrequentAccess"
  type        = string
  default     = "Standard"
}

variable "jurisdiction" {
  description = "Data jurisdiction: default | eu | fedramp"
  type        = string
  default     = "default"
}

# ---------------------------------------------------------------------------
# CORS
# ---------------------------------------------------------------------------

variable "cors_rules" {
  description = "CORS rules for this bucket. Empty list disables CORS resource."
  type = list(object({
    id              = optional(string, null)
    max_age_seconds = optional(number, 3600)
    expose_headers  = optional(list(string), [])
    allowed = object({
      methods = list(string)
      origins = list(string)
      headers = optional(list(string), [])
    })
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Lifecycle rules
# ---------------------------------------------------------------------------

variable "lifecycle_rules" {
  description = "Lifecycle rules for this bucket. Empty list disables lifecycle resource."
  type = list(object({
    id      = string
    enabled = optional(bool, true)
    prefix  = optional(string, "")

    # Delete objects older than N days
    delete_after_days = optional(number, null)

    # Abort in-progress multipart uploads older than N days
    abort_incomplete_multipart_upload_after_days = optional(number, null)

    # Move objects to InfrequentAccess after N days
    transition_to_infrequent_access_after_days = optional(number, null)
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Custom domain
# ---------------------------------------------------------------------------

variable "custom_domain" {
  description = "Optional custom domain for public bucket access."
  type = object({
    domain  = string
    zone_id = string
    enabled = optional(bool, true)
    min_tls = optional(string, "TLSv1.2")
  })
  default = null
}
