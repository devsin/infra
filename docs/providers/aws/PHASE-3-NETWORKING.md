# Phase 3: Networking

## 🎯 Objective

Create the network foundation for workload accounts:
- VPCs with public/private subnets
- NAT Gateways for outbound traffic
- VPC Endpoints for AWS services
- Route 53 hosted zones
- (Optional) Transit Gateway for inter-VPC connectivity

## 📋 What Gets Created Per Account/Region

| Resource | Count | Purpose |
|----------|-------|---------|
| VPC | 1 | Network isolation |
| Public Subnets | 3 | Load balancers, bastion |
| Private Subnets | 3 | EKS nodes, applications |
| NAT Gateway | 1-3 | Outbound internet |
| Internet Gateway | 1 | Inbound/outbound for public |
| VPC Endpoints | 5+ | AWS service access |
| Route Tables | 4+ | Traffic routing |

## 🏗️ Network Architecture

### VPC Design

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VPC: 10.X.0.0/16                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                    Availability Zone A                               │   │
│   │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │   │
│   │  │  Public Subnet   │  │ Private Subnet   │  │ Database Subnet  │   │   │
│   │  │  10.X.0.0/24     │  │ 10.X.10.0/24     │  │ 10.X.20.0/24     │   │   │
│   │  │  (ALB, NAT)      │  │ (EKS nodes)      │  │ (RDS, ElastiCache)│  │   │
│   │  └──────────────────┘  └──────────────────┘  └──────────────────┘   │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                    Availability Zone B                               │   │
│   │  (same subnet pattern)                                               │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                    Availability Zone C                               │   │
│   │  (same subnet pattern)                                               │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### CIDR Allocation Strategy

CIDRs are assigned per brand, with each environment getting a /16 within the brand's range.
This avoids overlaps and supports future VPC peering or Transit Gateway.

Each `.tfvars` file specifies the VPC CIDR for that brand×env. Use a consistent
formula to avoid overlaps: `10.{brand_index * 10 + env_offset}.0.0/16` where
dev=0, stage=1, prod=2.

| Brand Index | dev | stage | prod |
|-------------|-----|-------|------|
| Shared (0) | `10.0.0.0/16` | — | — |
| 1st brand (1) | `10.10.0.0/16` | `10.11.0.0/16` | `10.12.0.0/16` |
| 2nd brand (2) | `10.20.0.0/16` | `10.21.0.0/16` | `10.22.0.0/16` |
| Nth brand (N) | `10.{N*10}.0.0/16` | `10.{N*10+1}.0.0/16` | `10.{N*10+2}.0.0/16` |

The actual CIDR is set per `.tfvars` file — no brand names in the Terraform code:

```hcl
# envs/acme-dev.tfvars  (example)
brand       = "acme"
environment = "dev"
account_id  = "111111111111"
vpc_cidr    = "10.10.0.0/16"
region      = "eu-west-1"
```

## 📁 Stack Structure

One set of Terraform files. Brand/env selection happens via `-var-file`:

```
stacks/phase-3-networking/
├── main.tf                  # VPC, endpoints, DNS modules
├── variables.tf             # brand, environment, vpc_cidr, etc.
├── outputs.tf
├── backend.tf               # Partial backend (key set at init)
├── providers.tf
└── envs/                    # One file per brand×env
    ├── shared.tfvars
    ├── acme-dev.tfvars      # ← your real brand names
    ├── acme-stage.tfvars
    ├── acme-prod.tfvars
    ├── widgets-dev.tfvars
    └── widgets-prod.tfvars
```

> **Adding a new brand/env?** Just create a new `.tfvars` file. No new folders or copied code.

## 📝 VPC Module

### modules/vpc/variables.tf

```hcl
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
}

variable "database_subnets" {
  description = "Database subnet CIDRs"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost saving)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
```

### modules/vpc/main.tf

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs              = var.azs
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS requirements
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = merge(var.tags, {
    Terraform = "true"
  })
}

# VPC Endpoints for cost reduction and security
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = flatten([
        module.vpc.private_route_table_ids,
        module.vpc.public_route_table_ids
      ])
      tags = { Name = "${var.vpc_name}-s3-endpoint" }
    }
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
      tags = { Name = "${var.vpc_name}-ecr-api-endpoint" }
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
      tags = { Name = "${var.vpc_name}-ecr-dkr-endpoint" }
    }
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
      tags = { Name = "${var.vpc_name}-sts-endpoint" }
    }
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      security_group_ids  = [aws_security_group.vpc_endpoints.id]
      tags = { Name = "${var.vpc_name}-logs-endpoint" }
    }
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.vpc_name}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.vpc_name}-vpc-endpoints"
  }
}
```

## 🌐 DNS Setup (in `{prefix}-shared`)

### dns.tf

```hcl
variable "org_domain" {
  description = "Organization domain"
  type        = string
}

variable "brand_domains" {
  description = "Map of brand name to domain"
  type        = map(string)
  # Example: { "acme" = "acme.com", "widgets" = "widgets.io" }
}

# Organization domain hosted zone
resource "aws_route53_zone" "org" {
  name = var.org_domain
}

# Brand domain hosted zones (dynamic)
resource "aws_route53_zone" "brands" {
  for_each = var.brand_domains
  name     = each.value
}

# Subdomain delegation example
# For each brand/env, the workload account creates a hosted zone,
# then NS records are added here to delegate:
resource "aws_route53_record" "brand_env_ns" {
  for_each = var.brand_env_nameservers  # map of "dev.acme.com" => [ns1, ns2, ...]

  zone_id = aws_route53_zone.brands[each.value.brand].zone_id
  name    = each.key
  type    = "NS"
  ttl     = 300
  records = each.value.nameservers
}
```

## 💰 Cost Optimization

### NAT Gateway Strategy

| Environment | Strategy | Monthly Cost |
|-------------|----------|--------------|
| Dev | Single NAT Gateway | ~$35 + data |
| Stage | Single NAT Gateway | ~$35 + data |
| Prod | NAT per AZ (HA) | ~$105 + data |

### VPC Endpoint Savings

VPC Endpoints reduce NAT Gateway data transfer costs:
- ECR pulls go through endpoint, not NAT
- S3 access via gateway endpoint (free)
- Estimated savings: 60-80% on NAT data transfer

## 🚀 Deployment Steps

```bash
cd stacks/phase-3-networking

# 1. Deploy shared services networking (DNS)
terraform init -reconfigure \
  -backend-config="key=networking/shared/terraform.tfstate"
terraform apply -var-file=envs/shared.tfvars

# 2. Deploy a workload VPC (repeat for each brand×env)
terraform init -reconfigure \
  -backend-config="key=networking/acme/dev/eu-west-1/terraform.tfstate"
terraform apply -var-file=envs/acme-dev.tfvars

# 3. Another brand×env — same stack, different tfvars
terraform init -reconfigure \
  -backend-config="key=networking/widgets/prod/eu-west-1/terraform.tfstate"
terraform apply -var-file=envs/widgets-prod.tfvars
```

> **Tip:** Wrap this in a Makefile or shell script:
> ```bash
> make apply PHASE=3 BRAND=acme ENV=dev REGION=eu-west-1
> ```

## ✅ Phase 3 Checklist

- [ ] `{prefix}-shared` VPC created with DNS hosted zones
- [ ] All workload VPCs created with correct CIDRs
- [ ] Subnets tagged for EKS
- [ ] NAT Gateways operational
- [ ] VPC Endpoints configured (S3, ECR, STS, Logs)
- [ ] DNS delegation set up for subdomains
- [ ] No CIDR overlaps between VPCs
- [ ] Security groups for VPC endpoints
