# ==============================================================================
# Railway Brand Stack — Variables
#
# Defines the shape of a brand's Railway workspace: projects, services,
# environments, variables, and custom domains.
# ==============================================================================

# --- Authentication ---

variable "railway_token" {
  description = "Railway API token for the brand's workspace"
  type        = string
  sensitive   = true
}

# --- Brand Identity ---

variable "brand_name" {
  description = "Brand name (e.g. the product name, used for naming)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}$", var.brand_name))
    error_message = "brand_name must be lowercase alphanumeric (max 20 chars), starting with a letter."
  }
}

variable "workspace_id" {
  description = "Railway workspace (team) ID. Required if token has access to multiple workspaces."
  type        = string
  default     = ""
}

# --- Environments ---

variable "environments" {
  description = "List of environment names to create (first one is the default)"
  type        = list(string)
  default     = ["dev", "prod"]
}

# --- Services ---

variable "services" {
  description = "Map of service definitions for this brand's Railway project"
  type = map(object({
    # Source (pick one)
    source_repo   = optional(string, null) # GitHub repo, e.g. "org/repo"
    source_branch = optional(string, null) # Branch for source_repo
    source_image  = optional(string, null) # Docker image

    # Build / runtime
    root_directory = optional(string, null)
    config_path    = optional(string, null)
    cron_schedule  = optional(string, null)

    # Volume (for databases)
    volume = optional(object({
      name       = string
      mount_path = string
    }), null)

    # Per-environment variables: env_name → { VAR_NAME = "value" }
    variables = optional(map(map(string)), {})

    # Per-environment custom domains: env_name → ["domain1", "domain2"]
    custom_domains = optional(map(list(string)), {})
  }))
  default = {}
}
