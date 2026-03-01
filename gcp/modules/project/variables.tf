
variable "name" {
  description = "Project display name (also used as project_id base)"
  type        = string
}

variable "project_id" {
  description = "Explicit project ID. If empty, uses var.name with random suffix."
  type        = string
  default     = ""
}

variable "folder_id" {
  description = "The folder ID to place this project under"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID to link"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the project"
  type        = map(string)
  default = {
    managed-by = "terraform"
  }
}

variable "activate_apis" {
  description = "List of Google APIs to enable on this project"
  type        = list(string)
  default     = []
}

variable "deletion_policy" {
  description = "Project deletion policy: PREVENT, ABANDON, or DELETE"
  type        = string
  default     = "PREVENT"

  validation {
    condition     = contains(["PREVENT", "ABANDON", "DELETE"], var.deletion_policy)
    error_message = "deletion_policy must be PREVENT, ABANDON, or DELETE."
  }
}

variable "auto_create_network" {
  description = "Whether to create the default VPC. Almost always false."
  type        = bool
  default     = false
}

variable "add_random_suffix" {
  description = "Append a random hex suffix to the project ID for uniqueness"
  type        = bool
  default     = true
}
