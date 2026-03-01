# ==============================================================================
# GitHub Actions — Secrets, Variables & Deployment Environments
#
# Configures the infra repo with CI/CD credentials and deployment gates.
# ==============================================================================

# ------------------------------------------------------------------------------
# Actions Secrets (e.g., GCP_WIF_PROVIDER)
# ------------------------------------------------------------------------------

resource "github_actions_secret" "this" {
  for_each = nonsensitive(toset(keys(var.actions_secrets)))

  repository      = var.infra_repo
  secret_name     = each.key
  plaintext_value = var.actions_secrets[each.key]

  depends_on = [module.repos]
}

# ------------------------------------------------------------------------------
# Actions Variables (e.g., GCP_BOOTSTRAP_SA, GCP_ORG_SA)
# ------------------------------------------------------------------------------

resource "github_actions_variable" "this" {
  for_each = var.actions_variables

  repository    = var.infra_repo
  variable_name = each.key
  value         = each.value

  depends_on = [module.repos]
}

# ------------------------------------------------------------------------------
# Deployment Environments
#
# Creates environments used by CI/CD workflows for deploy tracking.
# Apply gating is handled via workflow_dispatch (manual trigger) in
# the CI/CD workflows — no paid-plan environment protection needed.
# ------------------------------------------------------------------------------

resource "github_repository_environment" "this" {
  for_each = toset(var.environments)

  repository  = var.infra_repo
  environment = each.value

  depends_on = [module.repos]
}
