# Evidence

Screenshots taken while building and testing the system. Each one proves a success criterion from `docs/scope.md`.

| File | What it shows | Proves |
|---|---|---|
| `09-chain-one-curl-three-logs.png` | One curl, then receipt.generated → receipt.processed → notification.dispatched | Receipt chain |
| `10-pod-reaches-chain.png` | A pod in `kijani-staging` reaches the chain on the laptop (after the narrow ufw rule) | S6 seam |
| `12-staging-manual-smoke-pass.png` | Smoke test PASS, chain finished in 1 s | S6 |
| `14-pipeline-paused-at-approval.png` | Pipeline paused at *Approve Production* after the staging smoke test | S3 |
| `16-pipeline-all-green.png` | Full run: staging → approval → production → verify | Delivery end to end |
| `19-prometheus-rules-loaded.png` | Both alert rules loaded | Intelligence layer |
| `20-alert-firing-prometheus.png` | `KkPaymentsPodRestarting` FIRING | S5 |
| `21-alert-in-alertmanager.png` | The same alert received by Alertmanager, with namespace and pod labels | S5 |
| `23-error-rate-alert-firing.png` | `KkPaymentsHighErrorRate` FIRING (error fault, 1 req/s) | Track A monitoring requirement |

Missing numbers are screenshots I didn't keep.
