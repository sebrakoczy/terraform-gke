# ---- build stage ----
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod ./
COPY go.su[m] ./
COPY . .
# Generate go.sum if absent, then build a static, stripped binary.
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /app .

# ---- runtime stage: distroless, non-root, minimal attack surface ----
FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=build /app /app
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app"]
