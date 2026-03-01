# ==============================================================================
# GitHub Organization Stack — Repos, Actions, Environments
#
# Manages:
#   1. Repositories (via reusable module)
#   2. GitHub Actions secrets & variables (GCP WIF, SA emails, etc.)
#   3. Deployment environments (for CI/CD apply gating)
#
# The infra repo already exists and will be imported automatically
# on first apply (see import block below).
#
# Usage:
#   export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
#   cd github/stacks/org
#   tofu init
#   tofu plan
#   tofu apply
# ==============================================================================

# ------------------------------------------------------------------------------
# Repositories
# ------------------------------------------------------------------------------

module "repos" {
  source   = "../../modules/repository"
  for_each = var.repos

  name                   = each.key
  description            = each.value.description
  visibility             = each.value.visibility
  has_issues             = each.value.has_issues
  has_wiki               = each.value.has_wiki
  has_projects           = each.value.has_projects
  has_discussions        = each.value.has_discussions
  topics                 = each.value.topics
  auto_init              = each.value.auto_init
  homepage_url           = each.value.homepage_url
  delete_branch_on_merge = each.value.delete_branch_on_merge
  allow_merge_commit     = each.value.allow_merge_commit
  allow_squash_merge     = each.value.allow_squash_merge
  allow_rebase_merge     = each.value.allow_rebase_merge
  allow_auto_merge       = each.value.allow_auto_merge
  allow_update_branch    = each.value.allow_update_branch
  vulnerability_alerts   = each.value.vulnerability_alerts
  archive_on_destroy     = each.value.archive_on_destroy
  branch_protection      = each.value.branch_protection
}
