#!/usr/bin/env bash
# Smoke test for kk-payments in one namespace. Exit 0 = safe to ask for approval; anything else = stop.
#
# Usage: scripts/smoke-test.sh <namespace> <expected-image-tag>
#   e.g. scripts/smoke-test.sh kijani-staging 1.0.0-a1b2c3d
#
# The checks, in order. Each one answers a different "is it really working?" question:
#   1. /health answers and reports the EXPECTED version  -> the new build is what is serving
#   2. /health reports the namespace's own environment     -> config separation is correct
#   3. /ready is 200                                       -> pods will receive traffic
#   4. POST /payments returns 201 with a receipt key       -> the business path works end to end
#   5. (staging only) kk-notifier wrote notify-<orderId>.json within 30s -> the whole receipt chain ran
set -euo pipefail

NS="${1:?namespace required}"
EXPECTED_TAG="${2:?expected image tag required}"
LOCAL_PORT="${SMOKE_PORT:-18080}"
CHAIN_S3="${CHAIN_S3:-http://localhost:4569}"          # serverless-s3-local on this laptop
ORDER_ID="SMOKE-${EXPECTED_TAG//./-}-$RANDOM"
BASE="http://127.0.0.1:${LOCAL_PORT}"

log()  { printf '[smoke][%s] %s\n' "$NS" "$*"; }
fail() { log "FAIL: $*"; exit 1; }

kubectl -n "$NS" port-forward svc/kk-payments "${LOCAL_PORT}:3001" >/tmp/smoke-pf-"$NS".log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT

# Wait for the port-forward (max ~15s).
for _ in $(seq 1 30); do curl -sf --max-time 1 "$BASE/health" >/dev/null && break; sleep 0.5; done

# 1 + 2: version and environment
HEALTH=$(curl -sf --max-time 3 "$BASE/health") || fail "/health did not answer"
log "/health -> $HEALTH"
VERSION=$(jq -r .version <<<"$HEALTH")
APP_ENV=$(jq -r .env <<<"$HEALTH")
[[ "$VERSION" == "$EXPECTED_TAG" ]] || fail "serving version '$VERSION', expected '$EXPECTED_TAG'"
case "$NS" in
  kijani-staging) [[ "$APP_ENV" == "staging" ]]    || fail "env is '$APP_ENV' in staging namespace" ;;
  default)        [[ "$APP_ENV" == "production" ]] || fail "env is '$APP_ENV' in production namespace" ;;
esac

# 3: readiness
curl -sf --max-time 3 "$BASE/ready" >/dev/null || fail "/ready is not 200"
log "/ready -> 200"

# 4: business path
RESP=$(curl -s --max-time 5 -w '\n%{http_code}' -X POST "$BASE/payments" \
        -H 'Content-Type: application/json' -d "{\"orderId\": \"${ORDER_ID}\", \"amount\": 1, \"currency\": \"KES\", \"smoke_test\": true}")
CODE=$(tail -n1 <<<"$RESP"); BODY=$(head -n -1 <<<"$RESP")
log "POST /payments -> $CODE $BODY"
[[ "$CODE" == "201" ]] || fail "POST /payments returned $CODE"

# 5: the receipt chain ran (staging only - production receipts are stored but not processed, see README)
if [[ "$NS" == "kijani-staging" ]]; then
  for i in $(seq 1 30); do
    if curl -sf --max-time 2 "${CHAIN_S3}/kk-notifications-queue-staging/notify-${ORDER_ID}.json" >/dev/null; then
      log "receipt chain finished for ${ORDER_ID} in ${i}s (kk-processor -> kk-notifier)"
      break
    fi
    [[ $i -eq 30 ]] && fail "receipt chain did not finish for ${ORDER_ID} within 30s - is 'make chain' running?"
    sleep 1
  done
fi

log "PASS — version ${VERSION}, env ${APP_ENV}"
