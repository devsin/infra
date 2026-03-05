variable "cloudflare_api_token" {
  description = "Cloudflare API token. Set via TF_VAR_cloudflare_api_token or pass directly."
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

# ---------------------------------------------------------------------------
# Zones
# ---------------------------------------------------------------------------
# This stack is the single owner of all Cloudflare zones.
# One zone per brand domain. Zone IDs are output and consumed by brand stacks
# via terraform_remote_state — no copy-pasting from dashboards.
#
# Key is a stable label (e.g. "brand-1") used in outputs and remote state refs.
# ---------------------------------------------------------------------------

variable "zones" {
  description = "Map of zones to create. Key = stable label, value = zone config."
  type = map(object({
    zone_name = string
    type      = optional(string, "full") # full | partial | secondary
  }))
}
