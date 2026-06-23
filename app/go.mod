module github.com/srakoczy/gke-reference-platform/app

go 1.24

require (
	google.golang.org/grpc v1.79.3
	github.com/prometheus/client_golang v1.20.5
	go.opentelemetry.io/otel v1.31.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.31.0
	go.opentelemetry.io/otel/sdk v1.31.0
)
