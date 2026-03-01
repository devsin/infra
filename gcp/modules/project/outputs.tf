output "project_id" {
  description = "The project ID"
  value       = google_project.this.project_id
}

output "project_number" {
  description = "The project number"
  value       = google_project.this.number
}

output "project_name" {
  description = "The project display name"
  value       = google_project.this.name
}
