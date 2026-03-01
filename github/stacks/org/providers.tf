# ==============================================================================
# GitHub Provider
#
# Authentication: set GITHUB_TOKEN env var with a PAT that has these scopes:
#   - repo (full control of private repos)
#   - admin:org (manage org settings, teams, members)
#   - delete_repo (if you ever need to destroy repos)
#
# Create a PAT at: https://github.com/settings/tokens
# Fine-grained tokens are recommended when available.
#
# Usage:
#   export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
#   tofu plan
# ==============================================================================

provider "github" {
  owner = var.github_org
  token = var.github_token
}
