# Runbook — reference-app

## Deploy failed / rolled back
`--atomic` auto-rolls-back. Check: `helm history reference-app -n <ns>`,
then `kubectl -n <ns> describe deploy reference-app` and recent pipeline logs.

## High error-budget burn (page)
1. Confirm via Grafana SLO dashboard.
2. `kubectl -n <ns> rollout undo deploy/reference-app` if a recent deploy correlates.
3. Check upstream deps and saturation (CPU/mem vs limits).

## Image blocked at admission
Kyverno rejected an unsigned/untrusted image. Confirm the pipeline's
`cosign-sign` job ran on main and the policy subject/issuer match.
