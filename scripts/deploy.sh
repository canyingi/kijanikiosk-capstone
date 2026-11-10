#!/usr/bin/env bash
# Deploys one image to one namespace, using the SAME Deployment file for every environment.
# Jenkins calls this, and I can also run it by hand.
#
# Usage: scripts/deploy.sh <namespace> <full-image-ref>
#   e.g. scripts/deploy.sh kijani-staging docker.io/canyingi/kk-payments:1.0.0-a1b2c3d
set -euo pipefail
NS="${1:?namespace required}"; IMAGE="${2:?image required}"
cd "$(dirname "$0")/.."

# Refuse anything except my two namespaces, so a typo can't deploy somewhere unexpected.
[[ "$NS" == "kijani-staging" || "$NS" == "default" ]] || { echo "unknown namespace: $NS"; exit 1; }
# The ConfigMap must exist first (Ansible creates it). Fail here with a clear message
# instead of letting the pods crash-loop.
kubectl -n "$NS" get configmap kk-payments-config >/dev/null \
  || { echo "kk-payments-config missing in $NS — run infra/ansible/configure-environments.yml"; exit 1; }

sed "s|IMAGE_PLACEHOLDER|${IMAGE}|" k8s/kk-payments-deployment.yaml | kubectl -n "$NS" apply -f -
kubectl -n "$NS" apply -f k8s/kk-payments-service.yaml
kubectl -n "$NS" annotate deployment/kk-payments --overwrite \
  "kubernetes.io/change-cause=deploy ${IMAGE} by ${BUILD_TAG:-manual}"
kubectl -n "$NS" rollout status deployment/kk-payments --timeout=180s
