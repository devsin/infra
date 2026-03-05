# ==============================================================================
# Cloudflare Org Stack
#
# Owns all zone creation. Brand stacks are consumers — they read zone IDs from
# this stack's remote state and never create or look up zones themselves.
#
# Apply order:
#   1. tofu apply here  → creates zones, outputs zone IDs + nameservers
#   2. Update registrar → point domain NS records to Cloudflare nameservers
#   3. tofu apply brand → creates DNS records, R2 buckets, zone settings
# ==============================================================================

resource "cloudflare_zone" "this" {
  for_each = var.zones

  account = { id = var.account_id }
  name    = each.value.zone_name
  type    = each.value.type
}
