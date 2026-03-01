# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "prefix" {
  description = "Short prefix for resource naming (e.g. company abbreviation)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,8}$", var.prefix))
    error_message = "Prefix must be 2-9 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "org_name" {
  description = "Organization name (used in tags)"
  type        = string
}

variable "org_domain" {
  description = "Organization domain (used for email aliases)"
  type        = string
}

variable "brands" {
  description = "List of brand/product definitions"
  type = list(object({
    name   = string
    domain = string
    envs   = list(string)
  }))

  validation {
    condition     = length(var.brands) > 0
    error_message = "At least one brand must be defined."
  }

  validation {
    condition = alltrue([
      for b in var.brands : can(regex("^[a-z][a-z0-9-]{0,19}$", b.name))
    ])
    error_message = "Brand names must be lowercase alphanumeric (max 20 chars), starting with a letter."
  }
}

# ==============================================================================
# OPTIONAL VARIABLES
# ==============================================================================

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "enable_sandbox" {
  description = "Whether to create a sandbox account"
  type        = bool
  default     = false
}
