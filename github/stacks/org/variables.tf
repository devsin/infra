# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token. If null, the provider reads GITHUB_TOKEN env var."
  type        = string
  sensitive   = true
  default     = null
}

# ==============================================================================
# REPOSITORIES
# ==============================================================================

variable "repos" {
  description = "Map of repositories to manage. Key = repo name."
  type = map(object({
    description            = optional(string, "")
    visibility             = optional(string, "private")
    has_issues             = optional(bool, true)
    has_wiki               = optional(bool, false)
    has_projects           = optional(bool, false)
    has_discussions        = optional(bool, false)
    topics                 = optional(list(string), [])
    auto_init              = optional(bool, false)
    homepage_url           = optional(string, "")
    delete_branch_on_merge = optional(bool, true)
    allow_merge_commit     = optional(bool, false)
    allow_squash_merge     = optional(bool, true)
    allow_rebase_merge     = optional(bool, true)
    allow_auto_merge       = optional(bool, false)
    allow_update_branch    = optional(bool, true)
    vulnerability_alerts   = optional(bool, true)
    archive_on_destroy     = optional(bool, true)
    branch_protection = optional(object({
      required_reviews           = optional(number, 1)
      dismiss_stale_reviews      = optional(bool, true)
      require_code_owner_reviews = optional(bool, false)
      require_status_checks      = optional(list(string), [])
      strict_status_checks       = optional(bool, false)
      enforce_admins             = optional(bool, false)
      allow_force_pushes         = optional(bool, false)
      allow_deletions            = optional(bool, false)
    }), null)
  }))
  default = {}
}

# ==============================================================================
# GITHUB ACTIONS — secrets & variables for CI/CD
# ==============================================================================

variable "infra_repo" {
  description = "Name of the infrastructure repo (for Actions secrets/variables)"
  type        = string
  default     = "infra"
}

variable "actions_secrets" {
  description = "GitHub Actions secrets to set on the infra repo (name → value)"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "actions_variables" {
  description = "GitHub Actions variables to set on the infra repo (name → value)"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# DEPLOYMENT ENVIRONMENTS
# ==============================================================================

variable "environments" {
  description = "Deployment environments to create on the infra repo for apply gating"
  type        = list(string)
  default     = []
}
