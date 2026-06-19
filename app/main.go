// Package main is a small, well-instrumented HTTP service used as the workload
// for the reference platform. It demonstrates: liveness/readiness probes,
// Prometheus metrics, and OpenTelemetry tracing wired through env vars.
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

var requests = promauto.NewCounterVec(prometheus.CounterOpts{
	Name: "app_http_requests_total",
	Help: "Total HTTP requests by path and status.",
}, []string{"path", "status"})

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// initTracer configures an OTLP/HTTP trace exporter. The endpoint is taken from
// OTEL_EXPORTER_OTLP_ENDPOINT, so the same binary ships traces to Tempo on the
// kubeadm cluster or to Cloud Trace on GKE with no code change.
func initTracer(ctx context.Context) (func(context.Context) error, error) {
	if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") == "" {
		return func(context.Context) error { return nil }, nil // tracing disabled
	}
	exp, err := otlptracehttp.New(ctx)
	if err != nil {
		return nil, err
	}
	res, _ := resource.New(ctx, resource.WithAttributes(
		semconv.ServiceName(env("OTEL_SERVICE_NAME", "reference-app")),
	))
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	return tp.Shutdown, nil
}

func main() {
	ctx := context.Background()
	shutdown, err := initTracer(ctx)
	if err != nil {
		log.Fatalf("tracer init: %v", err)
	}
	defer shutdown(ctx)

	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		requests.WithLabelValues("/healthz", "200").Inc()
		w.WriteHeader(http.StatusOK)
	})
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		requests.WithLabelValues("/readyz", "200").Inc()
		w.WriteHeader(http.StatusOK)
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		tr := otel.Tracer("reference-app")
		_, span := tr.Start(r.Context(), "handle-root")
		defer span.End()
		requests.WithLabelValues("/", "200").Inc()
		w.Write([]byte("reference-platform: ok\n"))
	})

	srv := &http.Server{Addr: ":" + env("PORT", "8080"), Handler: mux}

	go func() {
		log.Printf("listening on %s", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	ctxShutdown, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctxShutdown) // graceful drain for zero-downtime rollouts
}
