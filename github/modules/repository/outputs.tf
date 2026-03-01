# ==============================================================================
# Repository Module — Outputs
# ==============================================================================

output "name" {
  description = "Repository name"
  value       = github_repository.this.name
}

output "full_name" {
  description = "Full name of the repository (org/repo)"
  value       = github_repository.this.full_name
}

output "html_url" {
  description = "URL to the repository on the web"
  value       = github_repository.this.html_url
}

output "ssh_clone_url" {
  description = "URL to clone via SSH"
  value       = github_repository.this.ssh_clone_url
}

output "http_clone_url" {
  description = "URL to clone via HTTPS"
  value       = github_repository.this.http_clone_url
}

output "node_id" {
  description = "GraphQL node ID"
  value       = github_repository.this.node_id
}

output "repo_id" {
  description = "GitHub ID of the repository"
  value       = github_repository.this.repo_id
}
