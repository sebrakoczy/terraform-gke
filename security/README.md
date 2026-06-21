# Phase 4 — Security, policy & secrets

The security capstone: least-privilege identity, externalized secrets, signed-image
enforcement, config hardening, and network segmentation — all as code.

| Control | File | JD line |
|---|---|---|
| Secrets from Secret Manager (no keys) | `external-secrets-gcp.yaml` + `terraform/secrets.tf` | secrets management |
| Signed-image admission enforcement | `kyverno-verify-images.yaml` | auditable/repeatable, supply chain |
| Restricted Pod Security + guardrails | `kyverno-hardening.yaml` | configuration hardening |
| Network segmentation (default-deny) | `network-policies.yaml` | network policies |
| Least-privilege IAM / Workload Identity | `terraform/iam.tf`, `terraform/secrets.tf` | least-privilege IAM |

All of these deploy declaratively (via the GitLab Agent / ArgoCD) the same way the
app does — security is part of the GitOps flow, not a manual afterthought.

Emerging alternative worth knowing: Kyverno's newer CEL-based `ImageValidatingPolicy`
and GCP-native Binary Authorization both cover signed-image admission; this repo uses
the well-established `ClusterPolicy`/`verifyImages` path.
