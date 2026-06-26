// Package main is a small, well-instrumented HTTP service used as the workload
// for the reference platform. It is deliberately minimal: its job is to
// demonstrate the four things every production workload needs to be operable —
//
//  1. health signals      (liveness + readiness, consumed by Kubernetes probes)
//  2. metrics             (Prometheus counter scraped by GMP -> Cloud Monitoring)
//  3. distributed tracing (OpenTelemetry -> OTLP -> Cloud Trace / Tempo)
//  4. graceful shutdown    (SIGTERM drain for zero-downtime rolling updates)
//
// Everything downstream in the platform keys off this file:
//   /metrics       -> chart ServiceMonitor/PodMonitoring -> SLO alert in Terraform
//   /healthz       -> Helm livenessProbe
//   /readyz        -> Helm readinessProbe
//   OTEL_..._ENDPOINT -> OTel collector -> Cloud Trace (GKE) or Tempo (on-prem)
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

// requests is a Prometheus COUNTER (monotonically increasing; you never
// decrement it — you query its rate() over time). The two labels let us slice
// by path and HTTP status, which is exactly what the SLO alert needs:
//
//	sum(rate(app_http_requests_total{status=~"5.."}[5m]))
//	  / sum(rate(app_http_requests_total[5m]))      = error ratio
//
// promauto auto-registers it with the default registry, so promhttp.Handler()
// on /metrics exposes it with no extra wiring.
var requests = promauto.NewCounterVec(prometheus.CounterOpts{
	Name: "app_http_requests_total",
	Help: "Total HTTP requests by path and status.",
}, []string{"path", "status"})

// env reads a config value from the environment with a fallback default.
// This is 12-factor config: the binary takes ALL its configuration from the
// environment, so the SAME immutable image runs unchanged on GKE and on the
// self-managed cluster — only the env vars differ. That portability is what
// makes promotion (staging -> prod) and multi-environment deploys safe.
func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// initTracer configures an OTLP/HTTP trace exporter. The endpoint is read from
// OTEL_EXPORTER_OTLP_ENDPOINT, so the same binary ships traces to Cloud Trace
// on GKE (via the OTel collector) or to Tempo on the kubeadm cluster — with no
// code change. If the endpoint is unset (e.g. running locally), tracing is a
// no-op, so the app still runs fine with no collector present.
func initTracer(ctx context.Context) (func(context.Context) error, error) {
	if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") == "" {
		return func(context.Context) error { return nil }, nil // tracing disabled
	}
	exp, err := otlptracehttp.New(ctx)
	if err != nil {
		return nil, err
	}
	// Tag every span with the service name so it's identifiable in the trace UI.
	res, _ := resource.New(ctx, resource.WithAttributes(
		semconv.ServiceName(env("OTEL_SERVICE_NAME", "reference-app")),
	))
	// WithBatcher batches spans before export instead of one HTTP call per span.
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	return tp.Shutdown, nil // returned so main can flush spans on exit
}

func main() {
	ctx := context.Background()

	shutdown, err := initTracer(ctx)
	if err != nil {
		log.Fatalf("tracer init: %v", err)
	}
	defer shutdown(ctx) // flush any buffered spans on shutdown

	mux := http.NewServeMux()

	// /metrics — the Prometheus scrape target. GMP (GKE) or kube-prometheus
	// (on-prem) hits this endpoint and stores app_http_requests_total.
	mux.Handle("/metrics", promhttp.Handler())

	// ----------------------------------------------------------------------
	// LIVENESS  (/healthz)  — wired to the chart's livenessProbe.
	//
	// Question it answers: "Is this process broken/wedged and in need of a
	// RESTART?"  If this probe FAILS, the kubelet KILLS and RESTARTS the
	// container. Therefore liveness must check the NARROWEST possible thing —
	// ideally only "is my HTTP loop still responsive." It must NOT check
	// external dependencies: if it did, an external blip (e.g. DB down) would
	// trigger an endless restart loop for a problem a restart cannot fix.
	//
	// Here it just returns 200: as long as the server can answer, the process
	// is alive. In a real app this stays this simple on purpose.
	// ----------------------------------------------------------------------
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		requests.WithLabelValues("/healthz", "200").Inc()
		w.WriteHeader(http.StatusOK)
	})

	// ----------------------------------------------------------------------
	// READINESS  (/readyz)  — wired to the chart's readinessProbe.
	//
	// Question it answers: "Can this pod serve traffic CORRECTLY right now?"
	// If this probe FAILS, Kubernetes REMOVES the pod from the Service's
	// endpoints (it stops receiving traffic) but does NOT restart it. This is
	// for transient "I can't serve right now" states — still booting, warming
	// a cache, or a hard dependency (DB) is temporarily unreachable. The pod
	// stays alive, keeps trying, and rejoins the Service when ready again.
	//
	// Readiness checks MORE than liveness: all the dependencies needed to
	// actually do the job. This app has no dependencies, so it's identical to
	// liveness here — but see the commented real-world version below for how it
	// would differ once a database/cache/downstream API is added.
	// ----------------------------------------------------------------------
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		requests.WithLabelValues("/readyz", "200").Inc()
		w.WriteHeader(http.StatusOK)
	})

	// ----------------------------------------------------------------------
	// REAL-WORLD readiness vs liveness (illustrative — commented out because
	// this reference app has no external dependencies):
	//
	//   // readiness: check the things I need to SERVE correctly.
	//   mux.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
	//       if err := db.PingContext(r.Context()); err != nil {
	//           w.WriteHeader(http.StatusServiceUnavailable) // 503 -> drop from Service
	//           return
	//       }
	//       // also: caches warm? downstream APIs reachable? migrations done?
	//       w.WriteHeader(http.StatusOK)
	//   })
	//
	//   // liveness: check ONLY that the process itself isn't deadlocked.
	//   mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
	//       // deliberately does NOT check the DB — a DB outage is not a reason
	//       // to restart a healthy process. 200 as long as the loop responds.
	//       w.WriteHeader(http.StatusOK)
	//   })
	//
	// STARTUP PROBE (the third probe type) — for slow-starting apps:
	//   A startupProbe disables the liveness and readiness probes until the app
	//   has finished booting. Without it, a slow boot (loading models, big
	//   migrations) can trip the liveness probe and cause a restart loop before
	//   the app ever comes up. You'd expose a dedicated endpoint (or reuse one)
	//   and configure it in the chart, e.g.:
	//
	//       startupProbe:
	//         httpGet: { path: /startupz, port: 8080 }
	//         failureThreshold: 30      # allow 30 * periodSeconds for boot
	//         periodSeconds: 5          # => up to 150s to start before liveness begins
	//
	//   This app boots instantly, so it needs no startup probe — but in an
	//   interview this is the senior nuance: startup probe gates the other two
	//   so slow boots don't get killed.
	//
	//   // example startup endpoint a startupProbe would target:
	//   mux.HandleFunc("/startupz", func(w http.ResponseWriter, _ *http.Request) {
	//       if !appFinishedBooting() {
	//           w.WriteHeader(http.StatusServiceUnavailable)
	//           return
	//       }
	//       w.WriteHeader(http.StatusOK)
	//   })
	// ----------------------------------------------------------------------

	// / — the actual work. Starts an OpenTelemetry span (this is what shows up
	// in Cloud Trace / Tempo) and increments the request counter.
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		tr := otel.Tracer("reference-app")
		_, span := tr.Start(r.Context(), "handle-root")
		defer span.End()
		requests.WithLabelValues("/", "200").Inc()
		w.Write([]byte("reference-platform: ok\n"))
	})

	// PORT is env-driven (12-factor) with a sane default.
	srv := &http.Server{Addr: ":" + env("PORT", "8080"), Handler: mux}

	// Start the server in a goroutine so main can block on the signal channel
	// below. ErrServerClosed is the expected error after a graceful Shutdown,
	// so we don't treat it as fatal.
	go func() {
		log.Printf("listening on %s", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()

	// ----------------------------------------------------------------------
	// GRACEFUL SHUTDOWN — the app side of zero-downtime rolling updates.
	//
	// On a rolling update or scale-down, Kubernetes sends SIGTERM to the pod.
	// We catch it, then srv.Shutdown stops accepting NEW connections while
	// letting in-flight requests finish (up to the 10s timeout). Without this,
	// every deploy would cut active requests and produce errors.
	//
	// SENIOR NUANCE: this drain timeout (10s) must be shorter than the pod's
	// terminationGracePeriodSeconds (default 30s) in the chart — otherwise
	// Kubernetes SIGKILLs the pod mid-drain and you lose the benefit.
	// ----------------------------------------------------------------------
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop // block here until a termination signal arrives

	ctxShutdown, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctxShutdown) // graceful drain for zero-downtime rollouts
}
