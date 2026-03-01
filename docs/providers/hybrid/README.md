# Hybrid Phases — README

## 🔮 Status: Future

The `hybrid/` directory is reserved for cross-cloud stacks that reference resources from **both AWS and GCP**. These stacks will be implemented when multi-cloud connectivity is needed.

## 📋 Planned Stacks

| Stack | Purpose | When |
|-------|---------|------|
| `interconnect/` | VPN tunnels between AWS VPCs and GCP VPCs | When workloads span clouds |
| `dns/` | Unified DNS (Route53 ↔ Cloud DNS delegation) | When brands use both clouds |
| `identity/` | Federated identity (AWS ↔ GCP cross-trust) | When CI/CD needs both clouds |
| `observability/` | Unified monitoring (Datadog, Grafana Cloud) | When observability spans clouds |

## 🏗️ How It Works

Hybrid stacks use **remote state** from both AWS and GCP:

```hcl
# hybrid/stacks/interconnect/main.tf

# Read AWS networking state
data "terraform_remote_state" "aws_networking" {
  backend = "s3"
  config = {
    bucket = "..."
    key    = "networking/brand-a/prod/eu-west-1/terraform.tfstate"
    region = "eu-west-1"
  }
}

# Read GCP networking state
data "terraform_remote_state" "gcp_networking" {
  backend = "gcs"
  config = {
    bucket = "..."
    prefix = "networking/brand-a/prod/europe-west1"
  }
}

# Create cross-cloud VPN
resource "aws_vpn_gateway" "to_gcp" { ... }
resource "google_compute_vpn_tunnel" "to_aws" { ... }
```

## 📁 Directory Structure

```
hybrid/
├── stacks/
│   ├── interconnect/     # Cross-cloud VPN/Interconnect
│   ├── dns/              # Unified DNS
│   ├── identity/         # Cross-cloud IAM federation
│   └── observability/    # Unified monitoring
└── modules/
    └── cross-cloud-vpn/  # Reusable VPN module
```

> **No hybrid stacks are implemented yet.** The directory structure exists to ensure the repo is ready when the need arises.
