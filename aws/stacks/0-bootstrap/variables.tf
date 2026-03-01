# ------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ------------------------------------------------------------------------------

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

variable "github_org" {
  description = "GitHub organization name for OIDC trust"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust (this infra repo)"
  type        = string
}

# ------------------------------------------------------------------------------
# OPTIONAL VARIABLES
# ------------------------------------------------------------------------------

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "state_bucket_force_destroy" {
  description = "Allow force-destroying the state bucket (set true only for testing)"
  type        = bool
  default     = false
}
