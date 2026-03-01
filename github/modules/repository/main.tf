# ==============================================================================
# Repository Module — creates a GitHub repository with optional branch protection
#
# Usage:
#   module "my_repo" {
#     source      = "../../modules/repository"
#     name        = "my-repo"
#     description = "My awesome repo"
#     visibility  = "private"
#     topics      = ["terraform", "infrastructure"]
#
#     branch_protection = {
#       required_reviews      = 1
#       dismiss_stale_reviews = true
#     }
#   }
#
# Importing an existing repo:
#   import {
#     to = module.repos["my-repo"].github_repository.this
#     id = "my-repo"
#   }
# ==============================================================================

resource "github_repository" "this" {
  name                   = var.name
  description            = var.description
  visibility             = var.visibility
  has_issues             = var.has_issues
  has_wiki               = var.has_wiki
  has_projects           = var.has_projects
  has_discussions        = var.has_discussions
  auto_init              = var.auto_init
  topics                 = var.topics
  homepage_url           = var.homepage_url
  delete_branch_on_merge = var.delete_branch_on_merge
  allow_merge_commit     = var.allow_merge_commit
  allow_squash_merge     = var.allow_squash_merge
  allow_rebase_merge     = var.allow_rebase_merge
  allow_auto_merge       = var.allow_auto_merge
  allow_update_branch    = var.allow_update_branch
  vulnerability_alerts   = var.vulnerability_alerts
  archive_on_destroy     = var.archive_on_destroy
}

# ------------------------------------------------------------------------------
# Branch Protection — applied to the default branch when configured
# ------------------------------------------------------------------------------

resource "github_branch_protection" "default" {
  count = var.branch_protection != null ? 1 : 0

  repository_id       = github_repository.this.node_id
  pattern             = var.default_branch
  enforce_admins      = var.branch_protection.enforce_admins
  allows_force_pushes = var.branch_protection.allow_force_pushes
  allows_deletions    = var.branch_protection.allow_deletions

  required_pull_request_reviews {
    required_approving_review_count = var.branch_protection.required_reviews
    dismiss_stale_reviews           = var.branch_protection.dismiss_stale_reviews
    require_code_owner_reviews      = var.branch_protection.require_code_owner_reviews
  }

  dynamic "required_status_checks" {
    for_each = length(var.branch_protection.require_status_checks) > 0 ? [1] : []
    content {
      strict   = var.branch_protection.strict_status_checks
      contexts = var.branch_protection.require_status_checks
    }
  }
}
