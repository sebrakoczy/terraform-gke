# Phase 3 — Observability

- Metrics: app exposes /metrics; ServiceMonitor scrapes it (Prometheus / GMP).
- Tracing: app emits OTLP; point OTEL_EXPORTER_OTLP_ENDPOINT at Tempo (kubeadm)
  or Cloud Trace (GKE) — no code change.
- Logging: stdout -> Loki (kubeadm) or Cloud Logging (GKE).
- SLOs: slo-rules.yaml provides multi-window burn-rate alerts.

JD coverage: Prometheus, Grafana, Cloud Logging, Cloud Monitoring, Cloud Trace.
