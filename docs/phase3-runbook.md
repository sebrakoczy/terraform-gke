# Phase 3 runbook — observability on GKE

Wires the app's existing signals (metrics, traces, logs) to GCP-native backends.
Run after the Phase 2 cluster is up.

## 0. Enable APIs (once)
    gcloud services enable monitoring.googleapis.com cloudtrace.googleapis.com \
        logging.googleapis.com telemetry.googleapis.com

## 1. Apply the observability Terraform
    cd terraform && terraform apply -var project_id=YOUR_PROJECT
Creates the OTel collector's Google SA (Cloud Trace agent, Workload-Identity
bound), the SLO burn alert policy, and the dashboard.

## 2. Deploy the collector + metrics scrape
Replace YOUR_PROJECT in observability/otel-collector.yaml (the KSA annotation), then:
    kubectl apply -f observability/otel-collector.yaml
    kubectl apply -f observability/gmp-podmonitoring.yaml
    kubectl apply -f observability/gmp-rules.yaml

## 3. Point the app at the collector
Redeploy the app with the OTLP endpoint set (via the pipeline or directly):
    helm upgrade --install reference-app chart/ -n production \
      --set image.repository="$IMAGE" --set image.tag="$TAG" \
      --set otel.endpoint="http://otel-collector.observability:4318"

## 4. Generate traffic, then verify
    kubectl -n production port-forward svc/reference-app 8080:80 &
    for i in $(seq 1 50); do curl -s localhost:8080/ >/dev/null; done

- Metrics: Cloud console -> Monitoring -> Metrics Explorer, PromQL:
  `sum by (path) (rate(app_http_requests_total[5m]))`
- Traces:  Cloud console -> Trace -> Trace Explorer (look for service reference-app)
- Logs:    Cloud console -> Logging -> Logs Explorer (resource: Kubernetes Container)
- SLO:     Monitoring -> Alerting shows the "fast error-budget burn" policy;
           Dashboards shows "reference-app SLO".

## Notes
- Metrics in PromQL use the friendly name (app_http_requests_total); in some
  console filters they appear as prometheus.googleapis.com/app_http_requests_total/counter.
- The app needs no GCP credentials for tracing — the collector holds them via
  Workload Identity. Only Phase 4 (Secret Manager) needs the app's own GSA.
- kubeadm equivalent: kube-prometheus-stack (ServiceMonitor) + Tempo + Loki, with
  the PrometheusRule in observability/slo-rules.yaml.

## JD coverage added in Phase 3
Prometheus (Managed Service for Prometheus), Grafana-compatible metrics, Cloud
Monitoring, Cloud Logging, Cloud Trace / distributed tracing, OpenTelemetry,
SLO-based alerting as code.
