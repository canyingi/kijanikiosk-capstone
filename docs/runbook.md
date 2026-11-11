# kk-payments Runbook

## KkPaymentsPodRestarting
**Meaning:** a kk-payments container restarted 2+ times in 10 minutes, so it cannot stay up.
1. `kubectl -n <ns> get pods -l app=kk-payments` (look for `CrashLoopBackOff` and the RESTARTS column).
2. `kubectl -n <ns> logs <pod> --previous` (the last JSON log line before exit usually names the cause).
3. `kubectl -n <ns> get cm kk-payments-config -o yaml` (is `FAULT_MODE` anything other than `none`? Was a value changed recently?).
4. If it started after a deploy: `kubectl -n <ns> rollout undo deployment/kk-payments`.
5. If config is wrong: `make config` (Ansible restores desired state), then `kubectl -n <ns> rollout restart deployment/kk-payments`.

## KkPaymentsHighErrorRate
**Meaning:** more than 5% of `/payments` requests returned 5xx over 5 minutes, with real traffic.
1. Errors in logs: `kubectl -n <ns> logs -l app=kk-payments --since=10m | jq -c 'select(.level=="error")'`
2. `ECONNREFUSED` or `NoSuchBucket` means receipt storage is unreachable. Check MinIO is up and `RECEIPTS_BUCKET` / `S3_ENDPOINT` in the ConfigMap.
3. If it started after a release, roll back (step 4 above) and open an issue with the build number.

## Rollback (any environment)
```bash
kubectl -n <ns> rollout history deployment/kk-payments     # change-cause shows image + build
kubectl -n <ns> rollout undo deployment/kk-payments [--to-revision=N]
kubectl -n <ns> rollout status deployment/kk-payments
```
