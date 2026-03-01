# Phase 6: Workloads (GCP)

## 🎯 Objective

Deploy application workloads via GitOps:
- Kubernetes manifests managed by Argo CD
- Brand-specific application configurations
- Same GitOps pattern as AWS (unified Argo CD workflow)

## 📋 GitOps Structure

The GitOps layer is **cloud-agnostic** by design — Argo CD deploys Kubernetes manifests regardless of whether the cluster is EKS or GKE.

```
gitops/
├── brands.yaml                  # Brand definitions
├── scaffold.sh                  # Auto-generates brand directories
├── base/                        # Shared manifests
│   ├── namespaces/
│   └── network-policies/
├── apps/
│   ├── brand-a/                 # Auto-generated from brands.yaml
│   │   ├── dev/
│   │   ├── stage/
│   │   └── prod/
│   └── brand-b/
│       ├── dev/
│       └── prod/
└── argocd/
    ├── appprojects/
    └── applicationsets/
```

## 🔑 Cloud-Agnostic GitOps

The key insight: **Phase 6 is identical for AWS and GCP.** The Kubernetes manifests don't care which cloud the cluster runs on. The only differences are:

| Concern | AWS (EKS) | GCP (GKE) |
|---------|-----------|-----------|
| Ingress class | `alb` | `gce` or `nginx` |
| Service annotations | ALB annotations | NEG annotations |
| IAM for pods | IRSA annotations | Workload Identity annotations |
| Container registry | `ACCOUNT.dkr.ecr.REGION.amazonaws.com` | `REGION-docker.pkg.dev/PROJECT/REPO` |

These differences are handled via Kustomize overlays per cloud:

```yaml
# base/deployment.yaml — cloud-agnostic
apiVersion: apps/v1
kind: Deployment
...

# overlays/aws/kustomization.yaml
# overlays/gcp/kustomization.yaml
```

## ✅ Phase 6 Checklist

- [ ] Argo CD connected to GKE clusters
- [ ] ApplicationSets generating per-brand apps
- [ ] Brand directories auto-scaffolded from brands.yaml
- [ ] Applications deploying successfully
- [ ] Cloud-specific overlays working (GKE ingress, Workload Identity)
