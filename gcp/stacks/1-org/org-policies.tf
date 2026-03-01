# ==============================================================================
# Organization Policies — Guardrails (GCP equivalent of AWS SCPs)
#
# Applied at the org level to enforce security baselines.
# Uses google_org_policy_policy (v2 API) for fine-grained control.
#
# These are the Phase 1 baseline policies. Later phases can add more
# (e.g., Phase 3 adds network-specific constraints).
# ==============================================================================

# -- Helpers --

locals {
  org_parent = "organizations/${local.org_id}"
}

# ==============================================================================
# 1. Disable Default Service Account Grants
#    Prevents auto-granting Editor role to default compute/appspot SAs
# ==============================================================================

resource "google_org_policy_policy" "disable_default_sa_grants" {
  name   = "${local.org_parent}/policies/iam.automaticIamGrantsForDefaultServiceAccounts"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# ==============================================================================
# 2. Disable Service Account Key Creation
#    Forces Workload Identity / SA impersonation instead of exported keys
# ==============================================================================

resource "google_org_policy_policy" "disable_sa_key_creation" {
  name   = "${local.org_parent}/policies/iam.disableServiceAccountKeyCreation"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# ==============================================================================
# 3. Enforce Uniform Bucket-Level Access
#    Disables per-object ACLs on Cloud Storage buckets
# ==============================================================================

resource "google_org_policy_policy" "uniform_bucket_access" {
  name   = "${local.org_parent}/policies/storage.uniformBucketLevelAccess"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# ==============================================================================
# 4. Disable Serial Port Access
#    Prevents SSH-over-serial to Compute Engine instances
# ==============================================================================

resource "google_org_policy_policy" "disable_serial_port" {
  name   = "${local.org_parent}/policies/compute.disableSerialPortAccess"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# ==============================================================================
# 5. Require Shielded VMs
#    All Compute Engine instances must use Shielded VM features
# ==============================================================================

resource "google_org_policy_policy" "require_shielded_vm" {
  name   = "${local.org_parent}/policies/compute.requireShieldedVm"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# ==============================================================================
# 6. Restrict Public IP on Cloud SQL
#    Prevents Cloud SQL instances from having public IPs
# ==============================================================================

resource "google_org_policy_policy" "restrict_sql_public_ip" {
  name   = "${local.org_parent}/policies/sql.restrictPublicIp"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# ==============================================================================
# 7. Disable Nested Virtualization
#    Prevents running VMs inside VMs (reduces attack surface)
# ==============================================================================

resource "google_org_policy_policy" "disable_nested_virtualization" {
  name   = "${local.org_parent}/policies/compute.disableNestedVirtualization"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# ==============================================================================
# 8. Require OS Login
#    Forces OS Login for SSH access to Compute Engine instances
# ==============================================================================

resource "google_org_policy_policy" "require_os_login" {
  name   = "${local.org_parent}/policies/compute.requireOsLogin"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
