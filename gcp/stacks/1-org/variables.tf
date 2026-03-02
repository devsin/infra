# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "state_bucket" {
  description = "GCS bucket name holding Phase 0 state (from bootstrap output)"
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

variable "default_region" {
  description = "Default GCP region"
  type        = string
  default     = "europe-west1"
}

variable "enable_sandbox" {
  description = "Whether to create a sandbox folder and project"
  type        = bool
  default     = false
}

variable "folder_deletion_protection" {
  description = "Prevent Terraform from destroying folders"
  type        = bool
  default     = true
}

variable "project_deletion_policy" {
  description = "Project deletion policy: PREVENT, ABANDON, or DELETE"
  type        = string
  default     = "PREVENT"

  validation {
    condition     = contains(["PREVENT", "ABANDON", "DELETE"], var.project_deletion_policy)
    error_message = "project_deletion_policy must be PREVENT, ABANDON, or DELETE."
  }
}

# TODO: Uncomment when platform projects are needed.
# variable "platform_apis" {
#   description = "APIs to enable on platform projects"
#   type        = list(string)
#   default = [
#     "logging.googleapis.com",
#     "monitoring.googleapis.com",
#     "cloudresourcemanager.googleapis.com",
#     "serviceusage.googleapis.com",
#     "cloudasset.googleapis.com",
#   ]
# }

variable "workload_apis" {
  description = "APIs to enable on workload (brand) projects"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "run.googleapis.com",
    "iap.googleapis.com",
    "secretmanager.googleapis.com",
    "people.googleapis.com",
  ]
}
