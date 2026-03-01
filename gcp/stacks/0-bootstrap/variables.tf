# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "org_id" {
  description = "GCP Organization ID (numeric)"
  type        = string
}

variable "billing_account" {
  description = "GCP Billing Account ID (format: XXXXXX-XXXXXX-XXXXXX)"
  type        = string
}

variable "org_name" {
  description = "Organization display name (used in labels)"
  type        = string
}

variable "org_domain" {
  description = "Organization domain (e.g. mycompany.com)"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or user that owns the repositories"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for infrastructure code"
  type        = string
}

# ==============================================================================
# OPTIONAL VARIABLES — naming & prefixes
# ==============================================================================

variable "prefix" {
  description = "Short prefix for resource naming (e.g. company abbreviation)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,8}$", var.prefix))
    error_message = "Prefix must be 2-9 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "project_prefix" {
  description = "Prefix for project IDs. Should be consistent across all phases."
  type        = string
  default     = "prj"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,3}$", var.project_prefix))
    error_message = "Project prefix must be 1-4 lowercase alphanumeric characters."
  }
}

variable "folder_prefix" {
  description = "Prefix for folder display names. Should be consistent across all phases."
  type        = string
  default     = "fldr"
}

variable "bucket_prefix" {
  description = "Prefix for GCS bucket names"
  type        = string
  default     = "bkt"
}

# ==============================================================================
# OPTIONAL VARIABLES — regions
# ==============================================================================

variable "default_region" {
  description = "Default region for resource creation"
  type        = string
  default     = "europe-west1"
}

# ==============================================================================
# OPTIONAL VARIABLES — protection & lifecycle
# ==============================================================================

variable "bucket_force_destroy" {
  description = "Allow deleting state bucket even if it contains objects"
  type        = bool
  default     = false
}

variable "kms_prevent_destroy" {
  description = "Prevent Terraform from destroying KMS keys"
  type        = bool
  default     = true
}

variable "folder_deletion_protection" {
  description = "Prevent Terraform from destroying folders"
  type        = bool
  default     = true
}

variable "project_deletion_policy" {
  description = "Deletion policy for created projects (PREVENT or ABANDON)"
  type        = string
  default     = "PREVENT"
}

# ==============================================================================
# OPTIONAL VARIABLES — parent folder override
# ==============================================================================

variable "parent_folder" {
  description = <<-EOT
    Optional — place all foundation resources under this folder instead of
    the organization root. Value is the numeric folder ID.
    Leave empty to place directly under the organization.
  EOT
  type        = string
  default     = ""
}
