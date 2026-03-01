# ==============================================================================
# Member Accounts
#
# Dynamically creates:
#   - Core platform accounts (security, log, shared)
#   - Workload accounts (brand × env)
#   - Optional sandbox account
# ==============================================================================

# ------------------------------------------------------------------------------
# Account Definitions
# ------------------------------------------------------------------------------

locals {
  # Core platform accounts (always created)
  core_accounts = [
    {
      name        = "${var.prefix}-security"
      email       = "aws+${var.prefix}-security@${var.org_domain}"
      ou_path     = "Platform/Security"
      environment = "platform"
      brand       = "platform"
    },
    {
      name        = "${var.prefix}-log"
      email       = "aws+${var.prefix}-log@${var.org_domain}"
      ou_path     = "Platform/Security"
      environment = "platform"
      brand       = "platform"
    },
    {
      name        = "${var.prefix}-shared"
      email       = "aws+${var.prefix}-shared@${var.org_domain}"
      ou_path     = "Platform/SharedServices"
      environment = "platform"
      brand       = "platform"
    },
  ]

  # Workload accounts (dynamic: brand × env)
  workload_accounts = flatten([
    for brand in var.brands : [
      for env in brand.envs : {
        name        = "${var.prefix}-${brand.name}-${env}"
        email       = "aws+${var.prefix}-${brand.name}-${env}@${var.org_domain}"
        ou_path     = "Workloads/${title(brand.name)}"
        environment = env
        brand       = brand.name
      }
    ]
  ])

  all_accounts = concat(local.core_accounts, local.workload_accounts)
}

# ------------------------------------------------------------------------------
# Member Accounts — Core + Workload
# ------------------------------------------------------------------------------

resource "aws_organizations_account" "accounts" {
  for_each = { for acc in local.all_accounts : acc.name => acc }

  name      = each.value.name
  email     = each.value.email
  parent_id = local.all_ous[each.value.ou_path].id

  role_name = "OrganizationAccountAccessRole"

  close_on_deletion = false

  tags = {
    Name        = each.value.name
    Environment = each.value.environment
    Brand       = each.value.brand
  }

  lifecycle {
    # Email changes are not supported after creation
    ignore_changes = [email]
  }

  depends_on = [
    aws_organizations_organizational_unit.level1,
    aws_organizations_organizational_unit.level2,
  ]
}

# ------------------------------------------------------------------------------
# Sandbox Account (optional)
# ------------------------------------------------------------------------------

resource "aws_organizations_account" "sandbox" {
  count = var.enable_sandbox ? 1 : 0

  name      = "${var.prefix}-sandbox"
  email     = "aws+${var.prefix}-sandbox@${var.org_domain}"
  parent_id = aws_organizations_organizational_unit.level1["Sandbox"].id

  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = false

  tags = {
    Name        = "${var.prefix}-sandbox"
    Environment = "sandbox"
    Brand       = "platform"
  }
}

# ------------------------------------------------------------------------------
# Account ID Lookup
# ------------------------------------------------------------------------------

locals {
  account_ids = {
    for name, account in aws_organizations_account.accounts : name => account.id
  }
}
