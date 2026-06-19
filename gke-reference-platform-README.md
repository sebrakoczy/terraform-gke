# GKE Reference Platform

A self-contained platform-engineering showcase: one small Go service delivered
through a security-embedded GitLab pipeline onto Kubernetes, instrumented for
observability, and governed by policy-as-code. Built to demonstrate every line
of a GCP / GKE / GitLab platform role.

## What it demonstrates (JD coverage map)

| JD requirement | Where it lives |
|---|---|
| GitLab CI/CD, reusable pipeline templates | `.gitlab-ci.yml`, `.gitlab/ci/*.yml` |
| Automated build / test / deploy | pipeline stages `validate`→`deploy-prod` |
| Embedded security & vulnerability scanning | `security.yml` + GitLab AST templates |
| Terraform IaC on GCP | `terraform/` |
| GKE operation, HA, resilience | `terraform/` (Autopilot) + chart probes, topology spread, atomic deploys |
| Helm packaging | `chart/` |
| Monitoring / logging / alerting | `chart/templates/servicemonitor.yaml`, `observability/` |
| Distributed tracing (Cloud Trace) | OTel in `app/main.go`, env-driven endpoint |
| Secrets mgmt, least-privilege IAM | `security/external-secrets-gcp.yaml`, Workload Identity |
| Config hardening | hardened `Dockerfile` + pod/container securityContext |
| Policy / auditable delivery | `security/kyverno-verify-images.yaml`, Cosign signing + SBOM |
| Networking fundamentals | Service, probes, ingress (Phase 2) |
| Python/Go proficiency | instrumented Go service |
| Documentation / runbooks / ADRs | `docs/` |

## Build phases
1. **GitLab CI/CD** — pipeline + app + Helm. Runs free on the kubeadm cluster. (this scaffold)
2. **GKE via Terraform** — ephemeral Autopilot cluster, Workload Identity.
3. **Observability** — Prometheus/GMP, Tempo/Cloud Trace, Loki/Cloud Logging, SLO alerts.
4. **Security & policy** — External Secrets, Kyverno admission, signing enforcement.

## Run Phase 1 locally
- Create a GitLab project, push this repo.
- Register a runner (or use shared runners) and the GitLab Agent for your kubeadm cluster.
- Pipeline builds, scans, signs, and deploys to `staging` on `main`; `production` is a manual gate.

> Replace `yourname` / `registry.example.com` / `YOUR_PROJECT` placeholders before first run.
> `cd app && go mod tidy` to generate go.sum.
