terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

# ---------------------------------------------------------------------------
# R2 bucket
# Import: tofu import module.<name>.cloudflare_r2_bucket.this <account_id>/<bucket_name>/<jurisdiction>
# ---------------------------------------------------------------------------

resource "cloudflare_r2_bucket" "this" {
  account_id    = var.account_id
  name          = var.bucket_name
  location      = var.location
  storage_class = var.storage_class
}

# ---------------------------------------------------------------------------
# CORS (created only when cors_rules is non-empty)
# ---------------------------------------------------------------------------

resource "cloudflare_r2_bucket_cors" "this" {
  count        = length(var.cors_rules) > 0 ? 1 : 0
  account_id   = var.account_id
  bucket_name  = cloudflare_r2_bucket.this.name
  jurisdiction = var.jurisdiction != "default" ? var.jurisdiction : null

  rules = [for r in var.cors_rules : {
    id              = r.id
    max_age_seconds = r.max_age_seconds
    expose_headers  = r.expose_headers
    allowed = {
      methods = r.allowed.methods
      origins = r.allowed.origins
      headers = r.allowed.headers
    }
  }]
}

# ---------------------------------------------------------------------------
# Lifecycle rules (created only when lifecycle_rules is non-empty)
# Maps human-friendly _days inputs to the provider's nested transition blocks.
# ---------------------------------------------------------------------------

resource "cloudflare_r2_bucket_lifecycle" "this" {
  count        = length(var.lifecycle_rules) > 0 ? 1 : 0
  account_id   = var.account_id
  bucket_name  = cloudflare_r2_bucket.this.name
  jurisdiction = var.jurisdiction != "default" ? var.jurisdiction : null

  rules = [for r in var.lifecycle_rules : {
    id      = r.id
    enabled = r.enabled
    conditions = {
      prefix = r.prefix
    }

    delete_objects_transition = r.delete_after_days != null ? {
      condition = {
        type    = "Age"
        max_age = r.delete_after_days
      }
    } : null

    abort_multipart_uploads_transition = r.abort_incomplete_multipart_upload_after_days != null ? {
      condition = {
        type    = "Age"
        max_age = r.abort_incomplete_multipart_upload_after_days
      }
    } : null

    storage_class_transitions = r.transition_to_infrequent_access_after_days != null ? [{
      storage_class = "InfrequentAccess"
      condition = {
        type    = "Age"
        max_age = r.transition_to_infrequent_access_after_days
      }
    }] : null
  }]
}

# ---------------------------------------------------------------------------
# Custom domain (created only when custom_domain is set)
# Requires a DNS zone managed in the same Cloudflare account.
# ---------------------------------------------------------------------------

resource "cloudflare_r2_custom_domain" "this" {
  count       = var.custom_domain != null ? 1 : 0
  account_id  = var.account_id
  bucket_name = cloudflare_r2_bucket.this.name
  domain      = var.custom_domain.domain
  zone_id     = var.custom_domain.zone_id
  enabled     = var.custom_domain.enabled
  min_tls     = var.custom_domain.min_tls
}
