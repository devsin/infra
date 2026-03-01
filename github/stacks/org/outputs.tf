# ==============================================================================
# Outputs
# ==============================================================================

output "repositories" {
  description = "Map of managed repository details"
  value = {
    for name, repo in module.repos : name => {
      full_name      = repo.full_name
      html_url       = repo.html_url
      ssh_clone_url  = repo.ssh_clone_url
      http_clone_url = repo.http_clone_url
    }
  }
}

output "actions_secrets" {
  description = "Names of configured Actions secrets"
  value       = keys(github_actions_secret.this)
}

output "actions_variables" {
  description = "Names of configured Actions variables"
  value       = keys(github_actions_variable.this)
}

output "environments" {
  description = "Deployment environments created on the infra repo"
  value       = [for env in github_repository_environment.this : env.environment]
}
