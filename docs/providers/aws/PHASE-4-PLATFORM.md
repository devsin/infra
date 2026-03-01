# Phase 4: Platform Services

## 🎯 Objective

Deploy platform services that EKS clusters will depend on:
- ECR (Elastic Container Registry) repositories
- KMS (Key Management Service) keys
- S3 buckets for artifacts/backups
- Secrets Manager configuration
- Observability baseline (CloudWatch)

## 📋 What Gets Created Per Account

| Resource | Purpose |
|----------|---------|
| ECR Repositories | Container image storage |
| KMS Keys | Encryption (EKS secrets, S3, etc.) |
| S3 Buckets | Artifacts, backups, state |
| Secrets Manager | Application secrets |
| CloudWatch Log Groups | Centralized logging |
| CloudWatch Dashboards | Monitoring |

## 📁 Stack Structure

One set of Terraform files. Brand/env selection happens via `-var-file`:

```
stacks/phase-4-platform/
├── main.tf                  # ECR, KMS, S3, observability modules
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

## 📝 Key Resources

### ECR Repositories

```hcl
# modules/ecr/main.tf

variable "repository_names" {
  description = "List of ECR repository names (e.g. ['api', 'web', 'worker'])"
  type        = list(string)
}

variable "brand" {
  description = "Brand name prefix for repositories"
  type        = string
}

resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repository_names)

  name                 = "${var.brand}/${each.value}"
  image_tag_mutability = "MUTABLE"  # or IMMUTABLE for prod

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

### KMS Keys

```hcl
# modules/kms/main.tf

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secret encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEKSService"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-kms"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.name_prefix}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-s3-kms"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.name_prefix}-s3"
  target_key_id = aws_kms_key.s3.key_id
}
```

### Observability Baseline

```hcl
# modules/observability/main.tf

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "containers" {
  name              = "/aws/eks/${var.cluster_name}/containers"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EKS Node CPU"
          region  = var.region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${var.cluster_name}-nodes"]
          ]
        }
      }
    ]
  })
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.name_prefix}-alerts"
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeds 80%"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = "${var.cluster_name}-nodes"
  }

  tags = var.tags
}
```

## 🏗️ Example Stack

### stacks/phase-4-platform/main.tf

```hcl
terraform {
  backend "s3" {
    # bucket and dynamodb_table are fixed; key is set via -backend-config
    bucket         = ""  # Set via -backend-config
    key            = ""  # Set via -backend-config="key=platform/<brand>/<env>/<region>/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = ""  # Set via -backend-config
  }
}

provider "aws" {
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/${var.prefix}-automation"
  }

  default_tags {
    tags = {
      Company     = var.org_name
      Brand       = var.brand
      Environment = var.environment
      ManagedBy   = "terraform"
      Phase       = "4-platform"
    }
  }
}

locals {
  name_prefix  = "${var.prefix}-${var.brand}-${var.environment}"
  cluster_name = "${var.prefix}-${var.brand}-${var.environment}"
}

module "kms" {
  source      = "../../modules/kms"
  name_prefix = local.name_prefix
  tags        = {}
}

module "ecr" {
  source = "../../modules/ecr"

  brand            = var.brand
  repository_names = var.ecr_repositories  # e.g. ["api", "web", "worker"]
  kms_key_arn      = module.kms.eks_key_arn
  tags             = {}
}

module "s3" {
  source      = "../../modules/s3"
  name_prefix = local.name_prefix
  kms_key_arn = module.kms.s3_key_arn
  tags        = {}
}

module "observability" {
  source             = "../../modules/observability"
  name_prefix        = local.name_prefix
  cluster_name       = local.cluster_name
  region             = var.primary_region
  log_retention_days = var.environment == "dev" ? 30 : 90
  kms_key_arn        = module.kms.cloudwatch_key_arn
  tags               = {}
}
```

### Example envs/acme-dev.tfvars

```hcl
brand            = "acme"
environment      = "dev"
account_id       = "111111111111"
primary_region   = "eu-west-1"
ecr_repositories = ["api", "web", "worker"]
```

## 🚀 Deployment Steps

```bash
cd stacks/phase-4-platform

# Init with dynamic state key
terraform init -reconfigure \
  -backend-config="key=platform/acme/dev/eu-west-1/terraform.tfstate" \
  -backend-config="bucket=YOUR_PREFIX-terraform-state-MGMT_ACCOUNT_ID" \
  -backend-config="dynamodb_table=YOUR_PREFIX-terraform-lock"

# Plan and apply with brand-specific vars
terraform plan  -var-file=envs/acme-dev.tfvars
terraform apply -var-file=envs/acme-dev.tfvars

# Repeat for other brands/envs
terraform init -reconfigure \
  -backend-config="key=platform/widgets/prod/eu-west-1/terraform.tfstate" ...
terraform apply -var-file=envs/widgets-prod.tfvars
```

## ✅ Phase 4 Checklist

- [ ] KMS keys created for each purpose (EKS, S3, CloudWatch)
- [ ] ECR repositories created with scanning enabled
- [ ] ECR lifecycle policies in place
- [ ] S3 buckets created with encryption
- [ ] S3 public access blocked
- [ ] CloudWatch log groups created
- [ ] Basic dashboards in place
- [ ] SNS topics for alerts
- [ ] Outputs available for Phase 5 (EKS)
