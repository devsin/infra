# ==============================================================================
# Service Control Policies
#
# Base guardrails applied across the Organization:
#   - DenyLeaveOrganization  → all OUs
#   - DenyRootUserActions    → workloads, shared, sandbox
#   - BlockPublicS3          → workloads, shared, sandbox
#   - RegionRestriction      → workloads, sandbox
# ==============================================================================

# ------------------------------------------------------------------------------
# SCP: Deny Leaving Organization
# ------------------------------------------------------------------------------

resource "aws_organizations_policy" "deny_leave_org" {
  name        = "${var.prefix}-DenyLeaveOrganization"
  description = "Prevents accounts from leaving the organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLeaveOrganization"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-DenyLeaveOrganization"
  }
}

# ------------------------------------------------------------------------------
# SCP: Deny Root User Actions
# ------------------------------------------------------------------------------

resource "aws_organizations_policy" "deny_root_user" {
  name        = "${var.prefix}-DenyRootUserActions"
  description = "Prevents use of root user credentials in member accounts"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRootUser"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-DenyRootUserActions"
  }
}

# ------------------------------------------------------------------------------
# SCP: Block Public S3
# ------------------------------------------------------------------------------

resource "aws_organizations_policy" "block_public_s3" {
  name        = "${var.prefix}-BlockPublicS3"
  description = "Prevents public S3 bucket access"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicBucketACL"
        Effect = "Deny"
        Action = [
          "s3:PutBucketAcl",
          "s3:PutObjectAcl",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = [
              "public-read",
              "public-read-write",
              "authenticated-read",
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-BlockPublicS3"
  }
}

# ------------------------------------------------------------------------------
# SCP: Region Restriction
# ------------------------------------------------------------------------------

resource "aws_organizations_policy" "region_restriction" {
  name        = "${var.prefix}-RegionRestriction"
  description = "Restricts resource creation to allowed regions"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyNonAllowedRegions"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              var.primary_region,
            ]
          }
          # Exclude global services that always run in us-east-1
          ArnNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole",
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-RegionRestriction"
  }
}

# ==============================================================================
# SCP Attachments
# ==============================================================================

# --- DenyLeaveOrg → all top-level OUs ---

resource "aws_organizations_policy_attachment" "deny_leave_platform" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organizational_unit.level1["Platform"].id
}

resource "aws_organizations_policy_attachment" "deny_leave_workloads" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organizational_unit.level1["Workloads"].id
}

resource "aws_organizations_policy_attachment" "deny_leave_sandbox" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organizational_unit.level1["Sandbox"].id
}

# --- DenyRootUser → Workloads, SharedServices, Sandbox ---

resource "aws_organizations_policy_attachment" "deny_root_workloads" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.level1["Workloads"].id
}

resource "aws_organizations_policy_attachment" "deny_root_shared" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.level2["Platform/SharedServices"].id
}

resource "aws_organizations_policy_attachment" "deny_root_sandbox" {
  policy_id = aws_organizations_policy.deny_root_user.id
  target_id = aws_organizations_organizational_unit.level1["Sandbox"].id
}

# --- BlockPublicS3 → Workloads, SharedServices, Sandbox ---

resource "aws_organizations_policy_attachment" "block_s3_workloads" {
  policy_id = aws_organizations_policy.block_public_s3.id
  target_id = aws_organizations_organizational_unit.level1["Workloads"].id
}

resource "aws_organizations_policy_attachment" "block_s3_shared" {
  policy_id = aws_organizations_policy.block_public_s3.id
  target_id = aws_organizations_organizational_unit.level2["Platform/SharedServices"].id
}

resource "aws_organizations_policy_attachment" "block_s3_sandbox" {
  policy_id = aws_organizations_policy.block_public_s3.id
  target_id = aws_organizations_organizational_unit.level1["Sandbox"].id
}

# --- RegionRestriction → Workloads, Sandbox ---

resource "aws_organizations_policy_attachment" "region_restrict_workloads" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.level1["Workloads"].id
}

resource "aws_organizations_policy_attachment" "region_restrict_sandbox" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organizational_unit.level1["Sandbox"].id
}
