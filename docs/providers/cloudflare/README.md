# Cloudflare Platform Management

## Overview

Cloudflare manages **DNS, CDN, R2 object storage, TLS, and WAF** for all brands. It uses a two-stack architecture:

- **Org stack** — creates Cloudflare zones (one per domain). Applied once per org.
- **Brand stack** — manages DNS records, R2 buckets, zone settings (TLS/WAF/security), and custom domains. Applied per brand and environment.

## Architecture

```
cloudflare/stacks/org    (one per org — creates zones)
│
│   zones:
│     <brand-label>:  <brand-domain>    → Cloudflare zone + nameservers
│
└── outputs zone_ids → consumed by brand stacks via remote state

cloudflare/stacks/brand  (per brand × per environment)
│
│   <brand>-prod.tfvars
│   ├── Zone settings: TLS, WAF, security, performance
│   ├── DNS records:   api, web, email (MX, SPF, DKIM, DMARC)
│   └── R2 buckets:    uploads (with custom domain cdn.<brand-domain>)
│
│   <brand>-dev.tfvars
│   ├── DNS records:   api-dev, dev, cdn-dev (dev subdomains)
│   └── R2 buckets:    uploads (with custom domain cdn-dev.<brand-domain>)
│
└── manage_zone_settings = false  (dev defers to prod for zone-level settings)
```

> **Key design:** One Cloudflare zone per domain, shared across environments.
> Prod owns all zone-level settings (TLS, WAF, etc.). Dev only creates DNS
> records and R2 buckets — it sets `manage_zone_settings = false`.

## Directory Structure

```
cloudflare/
├── stacks/
│   ├── org/                     # Org-level: zone creation
│   │   ├── main.tf              #   cloudflare_zone resources
│   │   ├── variables.tf         #   account_id, zones map
│   │   ├── outputs.tf           #   zone_ids, name_servers
│   │   ├── providers.tf
│   │   ├── backend.tf
│   │   ├── versions.tf
│   │   └── envs/
│   │       └── <org>.tfvars     #   Zone definitions
│   │
│   └── brand/                   # Brand-level: DNS, R2, settings
│       ├── main.tf              #   zone + r2_bucket module calls
│       ├── variables.tf         #   Full zone + R2 config
│       ├── outputs.tf
│       ├── providers.tf
│       ├── backend.tf
│       ├── versions.tf
│       └── envs/
│           ├── <brand>-dev.tfvars
│           └── <brand>-prod.tfvars
│
└── modules/
    ├── zone/                    # Reusable zone module
    │   ├── main.tf              #   DNS, TLS, WAF, DNSSEC
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── r2-bucket/               # Reusable R2 bucket module
        ├── main.tf              #   Bucket, CORS, lifecycle, custom domain
        ├── variables.tf
        └── outputs.tf
```

## Terraform Provider

```hcl
# versions.tf
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}
```

## Authentication

Cloudflare uses an **API token** scoped to the account.

```hcl
# providers.tf
provider "cloudflare" {
  api_token = var.cloudflare_api_token  # or TF_VAR_cloudflare_api_token env var
}
```

> **Security:** Never commit tokens. Use `export TF_VAR_cloudflare_api_token="..."`.
> The token needs Zone:Edit, DNS:Edit, and R2:Edit permissions.

## Deployment: Org Stack

The org stack creates zones and outputs zone IDs + nameservers.

```bash
cd cloudflare/stacks/org
export TF_VAR_cloudflare_api_token="<your-api-token>"

tofu init -reconfigure \
  -backend-config="bucket=<gcs-tfstate-bucket>" \
  -backend-config="prefix=terraform/cloudflare/org/<org>"

tofu plan  -var-file=envs/<org>.tfvars
tofu apply -var-file=envs/<org>.tfvars

# After first apply — copy nameservers to your registrar:
tofu output name_servers
```

### Org tfvars Example

```hcl
# cloudflare/stacks/org/envs/<org>.tfvars
account_id = "<cloudflare-account-id>"

zones = {
  mybrand = {
    zone_name = "mybrand.com"
    type      = "full"
  }
}
```

## Deployment: Brand Stack

Brand stacks manage DNS records, R2 buckets, and zone settings.
Each brand gets **two tfvars files** — one for dev, one for prod.

```bash
cd cloudflare/stacks/brand
export TF_VAR_cloudflare_api_token="<your-api-token>"

# --- Prod (owns zone settings) ---
tofu init -reconfigure \
  -backend-config="bucket=<gcs-tfstate-bucket>" \
  -backend-config="prefix=terraform/cloudflare/<brand>-prod"
tofu plan  -var-file=envs/<brand>-prod.tfvars
tofu apply -var-file=envs/<brand>-prod.tfvars

# --- Dev (DNS records + R2 only) ---
tofu init -reconfigure \
  -backend-config="bucket=<gcs-tfstate-bucket>" \
  -backend-config="prefix=terraform/cloudflare/<brand>-dev"
tofu plan  -var-file=envs/<brand>-dev.tfvars
tofu apply -var-file=envs/<brand>-dev.tfvars
```

> **Apply order:** Always apply **prod first** (it creates zone settings),
> then dev (it only adds DNS records). The org stack must be applied before
> either brand stack.

## Zone Module Features

The `zone` module manages:

| Feature | Resource | Notes |
|---------|----------|-------|
| SSL/TLS mode | `cloudflare_zone_setting` | full, flexible, strict |
| Min TLS version | `cloudflare_zone_setting` | 1.0, 1.1, 1.2, 1.3 |
| TLS 1.3 | `cloudflare_zone_setting` | on/off |
| Always HTTPS | `cloudflare_zone_setting` | on/off |
| Auto HTTPS rewrites | `cloudflare_zone_setting` | on/off |
| Total TLS (ACM) | `cloudflare_total_tls` | Requires paid plan |
| Security level | `cloudflare_zone_setting` | off, low, medium, high, under_attack |
| WAF managed ruleset | `cloudflare_ruleset` | Requires Pro+ plan |
| Brotli | `cloudflare_zone_setting` | on/off |
| HTTP/3 | `cloudflare_zone_setting` | on/off |
| Browser cache TTL | `cloudflare_zone_setting` | seconds |
| DNSSEC | `cloudflare_zone_dnssec` | Requires DS record at registrar |
| DNS records | `cloudflare_dns_record` | A, AAAA, CNAME, MX, TXT, etc. |

## R2 Bucket Module Features

The `r2-bucket` module manages:

| Feature | Resource | Notes |
|---------|----------|-------|
| Bucket creation | `cloudflare_r2_bucket` | Named: `<org>-<brand>-<env>-<key>` |
| CORS rules | `cloudflare_r2_bucket` | Per-bucket allowed origins/methods |
| Lifecycle rules | `cloudflare_r2_bucket` | Expiration, abort incomplete uploads |
| Custom domain | `cloudflare_r2_custom_domain` | Serve via CDN (e.g., `cdn.<domain>`) |

## Free Plan Limitations

Cloudflare's Free plan has important restrictions:

| Feature | Free Plan | Pro+ Plan |
|---------|-----------|-----------|
| Universal SSL | `*.domain.tld` only | `*.domain.tld` |
| Total TLS (ACM) | Not available | `*.*.domain.tld` wildcards |
| WAF Managed Ruleset | Not available | Full WAF rule inspection |
| DDoS protection | Automatic (all plans) | Automatic (all plans) |

### SSL and Subdomains (Critical)

On the Free plan, Universal SSL only covers **single-level** subdomains:

```
✅ Works:    api.mybrand.com       (*.mybrand.com)
✅ Works:    dev.mybrand.com       (*.mybrand.com)
✅ Works:    cdn-dev.mybrand.com   (*.mybrand.com)
❌ Broken:   dev.api.mybrand.com   (*.*.mybrand.com — NOT covered)
❌ Broken:   dev.cdn.mybrand.com   (*.*.mybrand.com — NOT covered)
```

**Solution:** Use single-level dev subdomains with a hyphenated pattern:

| Environment | Pattern | Example |
|-------------|---------|---------|
| Prod | `<service>.<domain>` | `api.mybrand.com`, `cdn.mybrand.com` |
| Dev | `<service>-dev.<domain>` | `api-dev.mybrand.com`, `cdn-dev.mybrand.com` |
| Web (dev) | `dev.<domain>` | `dev.mybrand.com` |

## Key Variables

### Org Stack

```hcl
variable "account_id"   { type = string }
variable "zones" {
  type = map(object({
    zone_name = string
    type      = optional(string, "full")
  }))
}
```

### Brand Stack

```hcl
variable "org_name"      { }  # e.g. "myorg"
variable "brand_name"    { }  # e.g. "mybrand"
variable "environment"   { }  # "dev" or "prod"
variable "org_state_bucket" {} # GCS bucket with org stack state
variable "account_id"    { }

variable "zones" {
  type = map(object({
    zone_name            = string
    manage_zone_settings = optional(bool, true)   # false for dev
    ssl_mode             = optional(string, "full")
    min_tls_version      = optional(string, "1.2")
    # ... all zone settings (see variables.tf for full list)
    dns_records          = optional(map(object({...})), {})
  }))
}

variable "r2_buckets" {
  type = map(object({
    location      = optional(string, null)
    cors_rules    = optional(list(object({...})), [])
    lifecycle_rules = optional(list(object({...})), [])
    custom_domain = optional(object({
      domain     = string
      zone_label = string   # must match a key in the zones map
    }), null)
  }))
}
```

## State Management

| Stack | State Prefix |
|-------|-------------|
| Org | `terraform/cloudflare/org/<org>` |
| Brand (prod) | `terraform/cloudflare/<brand>-prod` |
| Brand (dev) | `terraform/cloudflare/<brand>-dev` |

## What Gets Managed

| Resource | Managed? | Notes |
|----------|----------|-------|
| Cloudflare account | No | Pre-created in Cloudflare dashboard |
| Zones | Yes (org stack) | One per domain |
| Zone settings | Yes (brand prod) | TLS, WAF, security, performance |
| DNS records | Yes (brand) | Per-environment records |
| R2 buckets | Yes (brand) | Per-environment buckets |
| R2 custom domains | Yes (brand) | CDN serving via custom domain |
| DNSSEC | Yes (brand) | Requires DS record at registrar |
| Registrar NS records | No | Update manually after first org apply |

## Considerations

### Cloudflare vs Cloud-Native CDN

Cloudflare is ideal for:
- Free TLS and DDoS protection on all proxied records
- R2 storage with zero-egress custom domain serving
- DNS management with global anycast
- Performance features (Brotli, HTTP/3) at no cost

For advanced WAF rules or wildcard subdomains (`*.*.domain`), upgrade to the Pro plan or use Total TLS via Advanced Certificate Manager.
