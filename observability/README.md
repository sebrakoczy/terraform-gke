# Phase 3 — Observability

Same app signals, two backends depending on where it runs.

| Signal  | GKE (this phase)                                  | kubeadm cluster                         |
|---------|---------------------------------------------------|-----------------------------------------|
| Metrics | Managed Service for Prometheus + `gmp-podmonitoring.yaml` | Prometheus + chart `ServiceMonitor`     |
| Traces  | OTel Collector (`otel-collector.yaml`) -> Cloud Trace | OTel Collector -> Tempo                 |
| Logs    | Cloud Logging (automatic on GKE)                  | Loki                                    |
| SLO     | Cloud Monitoring alert policy (`terraform/observability.tf`) + `gmp-rules.yaml` | `slo-rules.yaml` (PrometheusRule) |

The app is unchanged across both — only `OTEL_EXPORTER_OTLP_ENDPOINT` and the
scrape/alert backend differ. That portability is the point.
