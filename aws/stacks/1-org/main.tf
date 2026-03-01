# ==============================================================================
# Phase 1: Organization
#
# Creates the AWS Organization structure:
#   - Organization with all features enabled
#   - OU hierarchy (dynamic from var.brands)
#   - Service access principals for security services
#
# Deployment:
#   1. Update backend.tf with Phase 0 output values
#   2. terraform init
#   3. terraform apply -target=aws_organizations_organization.org
#   4. terraform apply -target=aws_organizations_organizational_unit.level1
#   5. terraform apply -target=aws_organizations_organizational_unit.level2
#   6. terraform apply   (accounts + SCPs)
# ==============================================================================

# ------------------------------------------------------------------------------
# Data Sources
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# Derived Locals — build OUs and accounts dynamically from var.brands
# ------------------------------------------------------------------------------

locals {
  account_id = data.aws_caller_identity.current.account_id

  # --- OU Structure ---

  # Static top-level OUs
  static_ous = [
    { name = "Platform", path = "Platform", parent_path = "" },
    { name = "Workloads", path = "Workloads", parent_path = "" },
    { name = "Sandbox", path = "Sandbox", parent_path = "" },
  ]

  # Static nested OUs under Platform
  platform_ous = [
    { name = "Security", path = "Platform/Security", parent_path = "Platform" },
    { name = "SharedServices", path = "Platform/SharedServices", parent_path = "Platform" },
  ]

  # Dynamic brand OUs under Workloads
  brand_ous = [
    for brand in var.brands : {
      name        = title(brand.name)
      path        = "Workloads/${title(brand.name)}"
      parent_path = "Workloads"
    }
  ]

  # Combined
  ou_structure = concat(local.static_ous, local.platform_ous, local.brand_ous)
  level1_ous   = [for ou in local.ou_structure : ou if ou.parent_path == ""]
  level2_ous   = [for ou in local.ou_structure : ou if ou.parent_path != ""]
}

# ------------------------------------------------------------------------------
# AWS Organization
# ------------------------------------------------------------------------------

resource "aws_organizations_organization" "org" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]

  feature_set = "ALL"
}

# ------------------------------------------------------------------------------
# Organizational Units — Level 1 (Platform, Workloads, Sandbox)
# ------------------------------------------------------------------------------

resource "aws_organizations_organizational_unit" "level1" {
  for_each = { for ou in local.level1_ous : ou.path => ou }

  name      = each.value.name
  parent_id = aws_organizations_organization.org.roots[0].id

  tags = {
    Name = each.value.name
    Path = each.value.path
  }
}

# ------------------------------------------------------------------------------
# Organizational Units — Level 2 (Security, SharedServices, brand OUs)
# ------------------------------------------------------------------------------

resource "aws_organizations_organizational_unit" "level2" {
  for_each = { for ou in local.level2_ous : ou.path => ou }

  name      = each.value.name
  parent_id = aws_organizations_organizational_unit.level1[each.value.parent_path].id

  tags = {
    Name = each.value.name
    Path = each.value.path
  }

  depends_on = [aws_organizations_organizational_unit.level1]
}

# ------------------------------------------------------------------------------
# Combined OU lookup — used by accounts.tf and scps.tf
# ------------------------------------------------------------------------------

locals {
  all_ous = merge(
    { for k, v in aws_organizations_organizational_unit.level1 : k => v },
    { for k, v in aws_organizations_organizational_unit.level2 : k => v },
  )
}
