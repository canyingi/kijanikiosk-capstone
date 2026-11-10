#!/usr/bin/env bash
# Demo helper: switch a deliberate fault on or off in ONE environment.
#
#   scripts/inject-fault.sh kijani-staging error   # /payments returns 500 -> smoke test fails, error-rate alert
#   scripts/inject-fault.sh kijani-staging crash   # process exits after 5s -> restarts -> restart alert
#   scripts/inject-fault.sh kijani-staging none    # clear the fault
#
# The fault is set in the ConfigMap, so anyone can see it with `kubectl get cm`.
# Re-running Ansible clears it, because the playbook always writes FAULT_MODE=none.
set -euo pipefail
NS="${1:?namespace required}"; MODE="${2:?mode required: none|error|crash}"
[[ "$MODE" =~ ^(none|error|crash)$ ]] || { echo "mode must be none|error|crash"; exit 1; }
[[ "$NS" == "default" ]] && { read -r -p "This is PRODUCTION. Type 'production' to continue: " c; [[ "$c" == "production" ]] || exit 1; }

kubectl -n "$NS" patch configmap kk-payments-config --type merge -p "{\"data\":{\"FAULT_MODE\":\"${MODE}\"}}"
kubectl -n "$NS" rollout restart deployment/kk-payments
echo "FAULT_MODE=${MODE} in ${NS} at $(date -u +%H:%M:%SZ)"
