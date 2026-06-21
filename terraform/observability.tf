resource "google_service_account" "otel" {
  account_id   = "${var.cluster_name}-otel"
  display_name = "OTel collector -> Cloud Trace"
}

resource "google_project_iam_member" "otel_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.otel.email}"
}

resource "google_service_account_iam_member" "otel_wi" {
  service_account_id = google_service_account.otel.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[observability/otel-collector]"
  depends_on         = [google_container_cluster.this]
}

# SLO alert policy is applied in PHASE 3, after the app metric exists in Cloud
# Monitoring. Cloud Monitoring validates PromQL metrics at creation time, so this
# must wait until Managed Prometheus has ingested app_http_requests_total once.
# resource "google_monitoring_alert_policy" "slo_fast_burn" {
#   display_name = "reference-app fast error-budget burn"
#   combiner     = "OR"
#   conditions {
#     display_name = "5xx ratio > 2% over 5m and 1h"
#     condition_prometheus_query_language {
#       query               = "(sum(rate(app_http_requests_total{status=~\"5..\"}[5m])) / sum(rate(app_http_requests_total[5m]))) > 0.02 and (sum(rate(app_http_requests_total{status=~\"5..\"}[1h])) / sum(rate(app_http_requests_total[1h]))) > 0.02"
#       duration            = "120s"
#       evaluation_interval = "60s"
#     }
#   }
#   documentation {
#     content = "Fast burn of the 99.9% availability SLO for reference-app."
#   }
# }

resource "google_monitoring_dashboard" "reference_app" {
  dashboard_json = jsonencode({
    displayName = "reference-app SLO"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title   = "Request rate by path"
            xyChart = { dataSets = [{ timeSeriesQuery = { prometheusQuery = "sum by (path) (rate(app_http_requests_total[5m]))" } }] }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title   = "5xx error ratio"
            xyChart = { dataSets = [{ timeSeriesQuery = { prometheusQuery = "sum(rate(app_http_requests_total{status=~\"5..\"}[5m])) / sum(rate(app_http_requests_total[5m]))" } }] }
          }
        }
      ]
    }
  })
}
