# Architecture decisions (ADR summary)

1. **Single reference workload, many platform concerns.** A small Go service is
   the vehicle; the value is the platform around it.
2. **GitLab CI as the delivery spine.** Push-based pipelines with reusable local
   templates + the GitLab Agent for pull-based deploys to Kubernetes.
3. **Cloud-agnostic core, cloud-specific edges.** App, Helm, policy, and
   observability instrumentation run unchanged on kubeadm or GKE; only identity,
   secrets backend, and tracing endpoint change.
4. **Security is in the pipeline, not bolted on.** SAST, dependency/container
   scanning, secret detection, SBOM, signing, and admission verification.
5. **Cost discipline.** GKE Autopilot, ephemeral apply/destroy, kubeadm for
   everything that doesn't require GCP.
