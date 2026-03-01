# ==============================================================================
# Repository Module — Variables
# ==============================================================================

variable "name" {
  description = "Repository name"
  type        = string
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = ""
}

variable "visibility" {
  description = "Repository visibility: public or private"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be 'public' or 'private'."
  }
}

variable "has_issues" {
  description = "Enable issues"
  type        = bool
  default     = true
}

variable "has_wiki" {
  description = "Enable wiki"
  type        = bool
  default     = false
}

variable "has_projects" {
  description = "Enable projects"
  type        = bool
  default     = false
}

variable "has_discussions" {
  description = "Enable discussions"
  type        = bool
  default     = false
}

variable "auto_init" {
  description = "Create initial commit with README (set false for existing repos)"
  type        = bool
  default     = false
}

variable "topics" {
  description = "Repository topics"
  type        = list(string)
  default     = []
}

variable "default_branch" {
  description = "Default branch name (used for branch protection pattern)"
  type        = string
  default     = "main"
}

variable "homepage_url" {
  description = "Homepage URL for the repository"
  type        = string
  default     = ""
}

variable "delete_branch_on_merge" {
  description = "Auto-delete head branches after merge"
  type        = bool
  default     = true
}

variable "allow_merge_commit" {
  description = "Allow merge commits"
  type        = bool
  default     = false
}

variable "allow_squash_merge" {
  description = "Allow squash merging"
  type        = bool
  default     = true
}

variable "allow_rebase_merge" {
  description = "Allow rebase merging"
  type        = bool
  default     = true
}

variable "allow_auto_merge" {
  description = "Allow auto-merge on pull requests"
  type        = bool
  default     = false
}

variable "allow_update_branch" {
  description = "Always suggest updating PR branches"
  type        = bool
  default     = true
}

variable "vulnerability_alerts" {
  description = "Enable Dependabot vulnerability alerts"
  type        = bool
  default     = true
}

variable "archive_on_destroy" {
  description = "Archive the repo instead of deleting on terraform destroy"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Branch Protection (optional)
# ------------------------------------------------------------------------------

variable "branch_protection" {
  description = "Branch protection configuration for the default branch. Set to null to skip."
  type = object({
    required_reviews           = optional(number, 1)
    dismiss_stale_reviews      = optional(bool, true)
    require_code_owner_reviews = optional(bool, false)
    require_status_checks      = optional(list(string), [])
    strict_status_checks       = optional(bool, false)
    enforce_admins             = optional(bool, false)
    allow_force_pushes         = optional(bool, false)
    allow_deletions            = optional(bool, false)
  })
  default = null
}
