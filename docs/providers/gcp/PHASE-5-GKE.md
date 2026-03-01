# Phase 5: GKE (GCP)

## 🎯 Objective

Deploy GKE clusters per brand/environment using the **proj service account**
(`sa-tf-proj`) from Phase 0:
- Private GKE cluster with Autopilot or Standard mode
- Workload Identity for pod-to-GCP-service authentication
- Core add-ons (Ingress controller, external-dns, cert-manager)
- GitOps bootstrap (Argo CD)

## 🔐 Authentication

```hcl
provider "google" {
  impersonate_service_account = data.terraform_remote_state.bootstrap.outputs.proj_sa_email
  region = var.default_region
}

terraform {
  backend "gcs" {
    bucket = "bkt-prj-b-seed-XXXX-tfstate"  # from Phase 0 output
    prefix = "terraform/gke"                 # + brand/env via -backend-config
  }
}
```

## 📋 What Gets Created

| Resource | Purpose | GCP Equivalent of |
|----------|---------|-------------------|
| GKE Cluster | Kubernetes cluster | EKS |
| Node Pools | Worker nodes | EKS Node Groups |
| Workload Identity | Pod IAM | IRSA |
| GKE Ingress | Load balancing | ALB Controller |
| Config Connector | GCP resources from K8s | ACK |

## 📝 Stack Pattern

Same flat pattern:

```
gcp/stacks/5-gke/
├── main.tf
├── variables.tf
├── outputs.tf
├── backend.tf
└── envs/
    ├── brand-a-dev.tfvars
    └── brand-a-prod.tfvars
```

## 📝 Key Resources

```hcl
resource "google_container_cluster" "main" {
  name     = "${var.prefix}-${var.brand}-${var.env}"
  project  = var.project_id
  location = var.primary_region

  # Remove default node pool immediately
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.vpc_id
  subnetwork = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = var.env == "prod" ? "STABLE" : "REGULAR"
  }

  # Binary authorization, network policy, etc.
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_V1"
  }
}

resource "google_container_node_pool" "main" {
  name     = "${var.prefix}-${var.brand}-${var.env}-main"
  project  = var.project_id
  location = var.primary_region
  cluster  = google_container_cluster.main.name

  autoscaling {
    min_node_count = var.env == "prod" ? 3 : 1
    max_node_count = var.env == "prod" ? 10 : 5
  }

  node_config {
    machine_type    = var.env == "prod" ? "e2-standard-4" : "e2-standard-2"
    service_account = var.gke_node_sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      brand       = var.brand
      environment = var.env
    }
  }
}
```

## 🔑 GKE vs EKS Comparison

| Feature | EKS (AWS) | GKE (GCP) |
|---------|-----------|-----------|
| Managed control plane | ✅ | ✅ |
| Serverless mode | Fargate | Autopilot |
| Pod IAM | IRSA (OIDC) | Workload Identity (native) |
| Ingress | ALB Controller (addon) | GKE Ingress (built-in) |
| Node autoscaling | Karpenter / Cluster Autoscaler | Node auto-provisioning |
| Release channels | — (manual upgrades) | Rapid / Regular / Stable |
| Network policy | Calico addon | Native Dataplane v2 |
| Cost optimization | Spot instances | Spot VMs + Preemptible |
| Config as Code | ACK | Config Connector |

> **Key advantage of GKE:** Workload Identity is native and simpler than IRSA. GKE also has built-in release channels for automatic control-plane upgrades.

## ✅ Phase 5 Checklist

- [ ] GKE cluster running per brand/env
- [ ] Node pools configured with autoscaling
- [ ] Workload Identity enabled
- [ ] Private cluster with authorized networks
- [ ] Release channel configured
- [ ] Core add-ons deployed (ingress, external-dns, cert-manager)
- [ ] GitOps tool (Argo CD) bootstrapped
