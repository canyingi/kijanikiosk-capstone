#!/usr/bin/env bash
# Prints exactly what is missing, so a new engineer doesn't have to guess.
set -uo pipefail
missing=0
need() { if command -v "$1" >/dev/null; then printf '  ok   %s\n' "$1"; else printf '  MISSING  %s  (%s)\n' "$1" "$2"; missing=1; fi; }

echo "Tools:"
need minikube  "https://minikube.sigs.k8s.io/docs/start/"
need kubectl   "https://kubernetes.io/docs/tasks/tools/"
need docker    "https://docs.docker.com/engine/install/ubuntu/"
need terraform ">= 1.10"
need ansible-playbook "pipx install ansible-core"
need helm      "https://helm.sh/docs/intro/install/"
need jq        "sudo apt install jq"
need node      "Node 20 via nvm (check: node --version)"

echo "Cluster:"
if [[ "$(kubectl config current-context 2>/dev/null)" == "minikube" ]]; then echo "  ok   context minikube"; else echo "  WRONG context: run 'minikube start' / 'kubectl config use-context minikube'"; missing=1; fi

echo "MinIO (Terraform state):"
if curl -sf --max-time 2 http://localhost:9000/minio/health/live >/dev/null; then echo "  ok   localhost:9000"; else echo "  DOWN  start MinIO (README > Setup)"; missing=1; fi

echo "Receipt chain (serverless-s3-local):"
if curl -s --max-time 2 -o /dev/null http://localhost:4569/; then echo "  ok   localhost:4569"; else echo "  DOWN  run 'make chain' in another terminal"; missing=1; fi

echo "Environment variables:"
for v in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY KK_DB_PASSWORD KK_STRIPE_API_KEY KK_JWT_SECRET DOCKERHUB_USER DOCKERHUB_TOKEN; do
  if [[ -n "${!v:-}" ]]; then echo "  ok   $v"; else echo "  UNSET $v  (see .env.example)"; missing=1; fi
done
exit $missing
