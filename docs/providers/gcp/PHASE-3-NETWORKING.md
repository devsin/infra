# Phase 3: Networking (GCP)

## 🎯 Objective

Provision network foundations per brand/environment using the **net service account**
(`sa-tf-net`) from Phase 0:
- VPC networks with subnets
- Cloud NAT for private egress
- Private Google Access for GCP services
- Cloud DNS zones
- Shared VPC (optional) or standalone VPCs

## 🔐 Authentication

```hcl
provider "google" {
  impersonate_service_account = data.terraform_remote_state.bootstrap.outputs.net_sa_email
  region = var.default_region
}

terraform {
  backend "gcs" {
    bucket = "bkt-prj-b-seed-XXXX-tfstate"  # from Phase 0 output
    prefix = "terraform/networking"           # + brand/env via -backend-config
  }
}
```

## 📋 What Gets Created

| Resource | Purpose | GCP Equivalent of |
|----------|---------|-------------------|
| VPC Network | Isolated network | AWS VPC |
| Subnets | Regional IP ranges | AWS Subnets |
| Cloud NAT | Private egress | NAT Gateway |
| Cloud Router | NAT + routing | Route tables |
| Firewall Rules | Network security | Security Groups |
| Cloud DNS | DNS resolution | Route53 |
| Private Google Access | GCP service access | VPC Endpoints |

## 📝 Stack Pattern

This is a **per-brand/env** stack using `envs/*.tfvars`:

```
gcp/stacks/3-networking/
├── main.tf
├── variables.tf
├── outputs.tf
├── backend.tf
└── envs/
    ├── brand-a-dev.tfvars
    ├── brand-a-prod.tfvars
    └── brand-b-dev.tfvars
```

Deploy per brand/env:
```bash
cd gcp/stacks/3-networking

terraform init -reconfigure \
  -backend-config="prefix=networking/acme/dev/europe-west1"

terraform plan  -var-file=envs/acme-dev.tfvars
terraform apply -var-file=envs/acme-dev.tfvars
```

## 📝 Key Resources

```hcl
resource "google_compute_network" "main" {
  name                    = "${var.prefix}-${var.brand}-${var.env}"
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private" {
  name                     = "${var.prefix}-${var.brand}-${var.env}-private"
  project                  = var.project_id
  region                   = var.primary_region
  network                  = google_compute_network.main.id
  ip_cidr_range            = var.private_subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.gke_services_cidr
  }
}

resource "google_compute_router" "main" {
  name    = "${var.prefix}-${var.brand}-${var.env}-router"
  project = var.project_id
  region  = var.primary_region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.prefix}-${var.brand}-${var.env}-nat"
  project                            = var.project_id
  region                             = var.primary_region
  router                             = google_compute_router.main.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
```

## 🔑 GCP vs AWS Networking Comparison

| Feature | AWS | GCP |
|---------|-----|-----|
| Network | VPC (regional) | VPC (global) |
| Subnets | AZ-scoped | Region-scoped |
| NAT | NAT Gateway (per AZ) | Cloud NAT (per region) |
| Service access | VPC Endpoints | Private Google Access |
| Cross-VPC | Transit Gateway / Peering | VPC Peering / Shared VPC |
| DNS | Route53 | Cloud DNS |
| Firewall | Security Groups + NACLs | VPC Firewall Rules |

> **Key difference:** GCP VPCs are global, subnets are regional. No AZ-level subnet planning needed.

## ✅ Phase 3 Checklist

- [ ] VPC created per brand/env project
- [ ] Subnets with secondary ranges for GKE
- [ ] Private Google Access enabled
- [ ] Cloud NAT configured
- [ ] Firewall rules baseline
- [ ] Cloud DNS zones configured
