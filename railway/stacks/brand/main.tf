# ==============================================================================
# Railway Brand Stack — Main
#
# Creates and manages a brand's Railway project:
#   1. Project (one per brand, contains all services)
#   2. Environments (dev, prod, etc.)
#   3. Services (web, api, db, workers, etc.)
#   4. Environment variables (per service, per environment)
#   5. Custom domains (per service, per environment)
#
# Architecture:
#   Workspace (<org>)                           ← pre-created, token-scoped
#   └── Project (<brand>)
#       ├── Environment: dev
#       │   ├── Service: <brand>-api            (from GitHub repo)
#       │   │   ├── Env vars: PORT, DATABASE_URL, ...
#       │   │   └── Domain: api.<brand-domain>
#       │   ├── Service: <brand>-web            (from GitHub repo)
#       │   │   ├── Env vars: PUBLIC_API_URL, ...
#       │   │   └── Domain: dev.<brand-domain>
#       │   └── Service: <brand>-db             (PostgreSQL volume)
#       ├── Environment: prod
#       │   └── ...
#       └── ...more environments
#
# Import existing resources:
#   See IMPORT.md in this directory for commands.
# ==============================================================================

# ------------------------------------------------------------------------------
# Project
# ------------------------------------------------------------------------------

resource "railway_project" "this" {
  name        = var.brand_name
  description = "${var.brand_name} services"
  private     = true

  default_environment = {
    name = var.environments[0]
  }
}

# ------------------------------------------------------------------------------
# Environments (additional — the first env is created as default above)
# ------------------------------------------------------------------------------

resource "railway_environment" "this" {
  for_each = toset(slice(var.environments, 1, length(var.environments)))

  name       = each.value
  project_id = railway_project.this.id
}

# ------------------------------------------------------------------------------
# Locals — environment ID lookup
# ------------------------------------------------------------------------------

locals {
  # Build a map of env_name → env_id for all environments
  environment_ids = merge(
    {
      (var.environments[0]) = railway_project.this.default_environment.id
    },
    {
      for name, env in railway_environment.this : name => env.id
    }
  )
}

# ------------------------------------------------------------------------------
# Services
# ------------------------------------------------------------------------------

resource "railway_service" "this" {
  for_each = var.services

  name       = each.key
  project_id = railway_project.this.id

  # Source — GitHub repo or Docker image
  source_repo        = each.value.source_repo
  source_repo_branch = each.value.source_branch
  source_image       = each.value.source_image

  # Build config
  root_directory = each.value.root_directory
  config_path    = each.value.config_path
  cron_schedule  = each.value.cron_schedule

  regions = [
    { region       = "europe-west4-drams3a",
      num_replicas = 1
    }
  ]

  # Volume (for database services)
  volume = each.value.volume != null ? {
    name       = each.value.volume.name
    mount_path = each.value.volume.mount_path
  } : null
}

# ------------------------------------------------------------------------------
# Environment Variables (per service, per environment)
# ------------------------------------------------------------------------------

locals {
  # Flatten: service_name × env_name × var_name → { key, service, env, name, value }
  service_env_vars = flatten([
    for svc_name, svc in var.services : [
      for env_name, vars in svc.variables : [
        for var_name, var_value in vars : {
          key     = "${svc_name}:${env_name}:${var_name}"
          service = svc_name
          env     = env_name
          name    = var_name
          value   = var_value
        }
      ]
    ]
  ])
}

resource "railway_variable" "this" {
  for_each = { for v in local.service_env_vars : v.key => v }

  name           = each.value.name
  value          = each.value.value
  environment_id = local.environment_ids[each.value.env]
  service_id     = railway_service.this[each.value.service].id
}

# ------------------------------------------------------------------------------
# Custom Domains (per service, per environment)
# ------------------------------------------------------------------------------

locals {
  # Flatten: service_name × env_name × domain → { key, service, env, domain }
  service_domains = flatten([
    for svc_name, svc in var.services : [
      for env_name, domains in svc.custom_domains : [
        for domain in domains : {
          key     = "${svc_name}:${env_name}:${domain}"
          service = svc_name
          env     = env_name
          domain  = domain
        }
      ]
    ]
  ])
}

resource "railway_custom_domain" "this" {
  for_each = { for d in local.service_domains : d.key => d }

  domain         = each.value.domain
  environment_id = local.environment_ids[each.value.env]
  service_id     = railway_service.this[each.value.service].id
}
