# Phase 4 — Security, policy & secrets

- Least-privilege identity: Workload Identity Federation (no static keys).
- Secrets: GCP Secret Manager via External Secrets Operator (rotated, not in Git).
- Admission policy: Kyverno verifies image signatures; blocks unsigned images.
- Supply chain: Cosign keyless signing + SBOM attestation (see pipeline).

JD coverage: secrets management, access controls, least-privilege IAM,
config hardening, vulnerability scanning, auditable/repeatable processes.
