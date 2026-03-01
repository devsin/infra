# ==============================================================================
# Tagging Module — Cross-Provider Tag/Label Normalization
#
# Generates consistent tags (AWS) and labels (GCP) from a single input.
# Handles provider-specific constraints:
#   - AWS tags: key 1-128 chars, value 0-256 chars, case-sensitive
#   - GCP labels: key 1-63 chars, value 0-63 chars, lowercase + hyphens only
#
# Usage:
#   module "tags" {
#     source      = "../../../modules/tagging"
#     prefix      = var.prefix
#     org_name    = var.org_name
#     environment = "prod"
#     brand       = "acme"
#     phase       = "1-org"
#   }
#
#   resource "aws_s3_bucket" "x" { tags = module.tags.aws }
#   resource "google_project" "x" { labels = module.tags.gcp }
# ==============================================================================

variable "prefix" {
  description = "Short prefix for resource naming"
  type        = string
}

variable "org_name" {
  description = "Organization name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod, platform, bootstrap)"
  type        = string
  default     = ""
}

variable "brand" {
  description = "Brand name (empty for org-level resources)"
  type        = string
  default     = ""
}

variable "phase" {
  description = "Infrastructure phase (e.g. 0-bootstrap, 1-org)"
  type        = string
  default     = ""
}

variable "extra_tags" {
  description = "Additional tags/labels to merge (will be normalized for each provider)"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Locals
# ==============================================================================

locals {
  # Common tag values (provider-agnostic)
  common = merge(
    {
      "managed-by" = "terraform"
    },
    var.environment != "" ? { "environment" = var.environment } : {},
    var.brand != "" ? { "brand" = var.brand } : {},
    var.phase != "" ? { "phase" = var.phase } : {},
    var.extra_tags,
  )

  # --- AWS tags: PascalCase keys, original values ---
  aws_key_map = {
    "managed-by"  = "ManagedBy"
    "environment" = "Environment"
    "brand"       = "Brand"
    "phase"       = "Phase"
    "company"     = "Company"
  }

  aws_base = merge(
    {
      "Company"   = var.org_name
      "ManagedBy" = "terraform"
    },
    var.environment != "" ? { "Environment" = var.environment } : {},
    var.brand != "" ? { "Brand" = var.brand } : {},
    var.phase != "" ? { "Phase" = var.phase } : {},
    {
      for k, v in var.extra_tags :
      try(local.aws_key_map[k], title(replace(k, "-", " "))) => v
    },
  )

  # --- GCP labels: lowercase keys with hyphens, values lowercase alphanumeric + hyphens ---
  gcp_base = {
    for k, v in local.common :
    lower(replace(k, "_", "-")) => lower(replace(v, "/[^a-z0-9-]/", "-"))
  }
}

# ==============================================================================
# Outputs
# ==============================================================================

output "aws" {
  description = "AWS-formatted tags (PascalCase keys)"
  value       = local.aws_base
}

output "gcp" {
  description = "GCP-formatted labels (lowercase, hyphens only)"
  value       = local.gcp_base
}

output "common" {
  description = "Provider-agnostic tag map (lowercase keys)"
  value       = local.common
}
