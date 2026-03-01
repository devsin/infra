# Phase 5: EKS (Kubernetes)

## 🎯 Objective

Deploy EKS (Elastic Kubernetes Service) clusters with:
- Cluster with private endpoint
- Managed node groups or Karpenter
- Core AWS add-ons
- Platform add-ons (ingress, DNS, secrets, etc.)
- IRSA (IAM Roles for Service Accounts)
- GitOps bootstrap (Argo CD)

## 📋 What Gets Created Per Cluster

| Resource | Purpose |
|----------|---------|
| EKS Cluster | Kubernetes control plane |
| Node Groups / Karpenter | Compute capacity |
| VPC CNI | Pod networking |
| CoreDNS | Cluster DNS |
| kube-proxy | Service networking |
| AWS Load Balancer Controller | Ingress/ALB |
| external-dns | DNS automation |
| cert-manager | TLS certificates |
| external-secrets | Secrets sync |
| Karpenter (optional) | Node autoscaling |
| Argo CD | GitOps deployment |
| IRSA Roles | Pod-level AWS access |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EKS Cluster                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                    Control Plane (AWS Managed)                       │   │
│   │  • API Server (private endpoint)                                     │   │
│   │  • etcd                                                              │   │
│   │  • Controller Manager                                                │   │
│   │  • Scheduler                                                         │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│   ┌────────────────────────────────┼────────────────────────────────────┐   │
│   │                    Data Plane (Your Account)                         │   │
│   │                                                                      │   │
│   │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│   │   │   Node (AZ-A)│  │   Node (AZ-B)│  │   Node (AZ-C)│              │   │
│   │   │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │              │   │
│   │   │  │  Pods  │  │  │  │  Pods  │  │  │  │  Pods  │  │              │   │
│   │   │  └────────┘  │  │  └────────┘  │  │  └────────┘  │              │   │
│   │   └──────────────┘  └──────────────┘  └──────────────┘              │   │
│   │                                                                      │   │
│   │   Platform Add-ons:                                                  │   │
│   │   • aws-load-balancer-controller                                     │   │
│   │   • external-dns                                                     │   │
│   │   • cert-manager                                                     │   │
│   │   • external-secrets                                                 │   │
│   │   • karpenter (optional)                                             │   │
│   │   • argo-cd                                                          │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📁 Stack Structure

One set of Terraform files. Brand/env selection happens via `-var-file`:

```
stacks/phase-5-eks/
├── main.tf                  # EKS cluster, IRSA, add-ons
├── variables.tf             # brand, environment, prefix, etc.
├── outputs.tf
├── backend.tf               # Partial backend (key set at init)
├── providers.tf
└── envs/                    # One file per brand×env
    ├── acme-dev.tfvars
    ├── acme-stage.tfvars
    ├── acme-prod.tfvars
    └── widgets-dev.tfvars
```

> No brand-named folders. Adding a new brand/env = adding a new `.tfvars` file.

## 📝 EKS Module

### modules/eks/main.tf

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access

  cluster_encryption_config = {
    provider_key_arn = var.kms_key_arn
    resources        = ["secrets"]
  }

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
    eks-pod-identity-agent = { most_recent = true }
  }

  enable_irsa = true
  eks_managed_node_groups = var.node_groups
  enable_cluster_creator_admin_permissions = true

  tags = var.tags
}
```

## 📦 IRSA (IAM Roles for Service Accounts)

```hcl
# modules/irsa/main.tf

module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${var.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                     = "${var.cluster_name}-external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = var.hosted_zone_arns

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                             = "${var.cluster_name}-external-secrets"
  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:*"]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
}

module "cert_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                     = "${var.cluster_name}-cert-manager"
  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = var.hosted_zone_arns

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }
}
```

## 📦 Helm Releases

```hcl
# modules/eks-addons/main.tf

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set { name = "clusterName"; value = var.cluster_name }
  set { name = "serviceAccount.create"; value = "true" }
  set { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"; value = var.alb_controller_role_arn }
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  namespace        = "external-dns"
  version          = "1.14.3"
  create_namespace = true

  set { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"; value = var.external_dns_role_arn }
  set { name = "provider"; value = "aws" }
  set { name = "policy"; value = "sync" }
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  version          = "1.14.4"
  create_namespace = true

  set { name = "installCRDs"; value = "true" }
  set { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"; value = var.cert_manager_role_arn }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  version          = "0.9.13"
  create_namespace = true

  set { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"; value = var.external_secrets_role_arn }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = "6.7.3"
  create_namespace = true

  values = [
    yamlencode({
      server = {
        extraArgs = ["--insecure"]
        ingress = {
          enabled = true
          annotations = {
            "kubernetes.io/ingress.class"               = "alb"
            "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"     = "ip"
            "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
          }
          hosts = ["argocd.${var.domain}"]
        }
      }
    })
  ]
}
```

## 🏗️ Example Stack

### stacks/phase-5-eks/main.tf

```hcl
terraform {
  backend "s3" {
    # bucket, dynamodb_table, and key are set via -backend-config at init time
    bucket         = ""
    key            = ""
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = ""
  }
}

provider "aws" {
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/${var.prefix}-automation"
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    }
  }
}

locals {
  cluster_name = "${var.prefix}-${var.brand}-${var.environment}"
  domain       = "${var.environment}.${var.brand_domain}"
}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "${var.prefix}-terraform-state-${var.mgmt_account_id}"
    key    = "networking/${var.brand}/${var.environment}/${var.primary_region}/terraform.tfstate"
    region = var.primary_region
  }
}

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "${var.prefix}-terraform-state-${var.mgmt_account_id}"
    key    = "platform/${var.brand}/${var.environment}/${var.primary_region}/terraform.tfstate"
    region = var.primary_region
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc_id                   = data.terraform_remote_state.networking.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.networking.outputs.private_subnet_ids
  control_plane_subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids

  kms_key_arn = data.terraform_remote_state.platform.outputs.eks_kms_key_arn

  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 5
      desired_size   = 2
      labels         = { role = "general" }
      taints         = []
    }
  }

  tags = {
    Environment = var.environment
    Brand       = var.brand
  }
}

module "irsa" {
  source            = "../../modules/irsa"
  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  hosted_zone_arns  = [data.terraform_remote_state.networking.outputs.hosted_zone_arn]
}

module "addons" {
  source = "../../modules/eks-addons"

  cluster_name              = local.cluster_name
  domain                    = local.domain
  certificate_arn           = data.terraform_remote_state.platform.outputs.certificate_arn
  alb_controller_role_arn   = module.irsa.alb_controller_role_arn
  external_dns_role_arn     = module.irsa.external_dns_role_arn
  cert_manager_role_arn     = module.irsa.cert_manager_role_arn
  external_secrets_role_arn = module.irsa.external_secrets_role_arn

  depends_on = [module.eks]
}
```

### Example envs/acme-dev.tfvars

```hcl
brand           = "acme"
environment     = "dev"
account_id      = "111111111111"
mgmt_account_id = "000000000000"
primary_region  = "eu-west-1"
brand_domain    = "acme.com"
cluster_version = "1.29"
```

## 🚀 Deployment Steps

```bash
cd stacks/phase-5-eks

# Init with dynamic state key
terraform init -reconfigure \
  -backend-config="key=eks/acme/dev/eu-west-1/terraform.tfstate" \
  -backend-config="bucket=YOUR_PREFIX-terraform-state-MGMT_ACCOUNT_ID" \
  -backend-config="dynamodb_table=YOUR_PREFIX-terraform-lock"

# Plan and apply with brand-specific vars
terraform plan  -var-file=envs/acme-dev.tfvars
terraform apply -var-file=envs/acme-dev.tfvars

# Verify cluster
aws eks update-kubeconfig \
  --name $(terraform output -raw cluster_name) \
  --region $(terraform output -raw region)
kubectl get nodes
kubectl get pods -A
```

## ✅ Phase 5 Checklist

- [ ] EKS cluster created and healthy
- [ ] Nodes running and ready
- [ ] VPC CNI configured with network policy support
- [ ] CoreDNS and kube-proxy running
- [ ] AWS Load Balancer Controller installed
- [ ] external-dns syncing records
- [ ] cert-manager issuing certificates
- [ ] external-secrets syncing from Secrets Manager
- [ ] IRSA roles working (pods can access AWS)
- [ ] Argo CD accessible and bootstrapped
- [ ] kubectl access working via SSO / OIDC
