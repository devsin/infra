# ==============================================================================
# Naming Module — Cross-Provider Naming Convention
#
# Generates consistent resource names for AWS, GCP, and other providers.
# All provider stacks should use this module to ensure naming consistency.
#
# Usage:
#   module "naming" {
#     source = "../../../modules/naming"
#     prefix = var.prefix
#     environment = "prod"
#     brand = "acme"
#   }
#
#   google_project.example { name = module.naming.project_name("web") }
#   aws_s3_bucket.example  { bucket = module.naming.bucket_name("logs") }
# ==============================================================================

variable "prefix" {
  description = "Short prefix for resource naming (e.g. company abbreviation)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,8}$", var.prefix))
    error_message = "Prefix must be 2-9 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name (e.g. dev, stage, prod, platform, bootstrap)"
  type        = string
  default     = ""
}

variable "brand" {
  description = "Brand name (empty for org-level resources)"
  type        = string
  default     = ""
}

variable "project_prefix" {
  description = "GCP project ID prefix"
  type        = string
  default     = "prj"
}

variable "folder_prefix" {
  description = "GCP folder display name prefix"
  type        = string
  default     = "fldr"
}

variable "bucket_prefix" {
  description = "GCS/S3 bucket name prefix"
  type        = string
  default     = "bkt"
}

# ==============================================================================
# Locals — build name segments
# ==============================================================================

locals {
  # Base segments: always [prefix]
  # With brand: [prefix, brand]
  # With brand + env: [prefix, brand, env]
  segments = compact([var.prefix, var.brand, var.environment])
  base     = join("-", local.segments)
}

# ==============================================================================
# Outputs
# ==============================================================================

output "base" {
  description = "Base name: {prefix}[-{brand}][-{env}] (e.g. mc-acme-prod)"
  value       = local.base
}

output "prefix" {
  description = "The prefix value (passthrough)"
  value       = var.prefix
}

output "project_prefix" {
  description = "GCP project prefix (passthrough)"
  value       = var.project_prefix
}

output "folder_prefix" {
  description = "GCP folder prefix (passthrough)"
  value       = var.folder_prefix
}

output "bucket_prefix" {
  description = "Bucket prefix (passthrough)"
  value       = var.bucket_prefix
}

# --- Name generators (use these in your stacks) ---

output "resource_name" {
  description = "Generic resource name: {prefix}[-{brand}][-{env}]"
  value       = local.base
}

output "gcp_project_id" {
  description = "GCP project ID: {project_prefix}[-{brand}][-{env}]"
  value       = join("-", compact([var.project_prefix, var.brand, var.environment]))
}

output "gcp_folder_name" {
  description = "GCP folder display name: {folder_prefix}-{purpose}"
  value       = var.folder_prefix
}

output "bucket_name" {
  description = "Bucket name: {bucket_prefix}-{prefix}[-{brand}][-{env}]"
  value       = join("-", compact([var.bucket_prefix, var.prefix, var.brand, var.environment]))
}

output "aws_account_name" {
  description = "AWS account name: {prefix}[-{brand}][-{env}]"
  value       = local.base
}

output "aws_account_email" {
  description = "AWS account email pattern (needs domain appended)"
  value       = "aws+${local.base}"
}
