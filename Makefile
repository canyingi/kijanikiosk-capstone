# One entry point for a new engineer. Run `make help`.
# Every target is a thin wrapper around a script or tool command documented in README.md.
SHELL := /bin/bash
NS_STAGING := kijani-staging

.PHONY: help check infra config chain monitoring deploy-staging smoke-staging test destroy

help:            ## List targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

check:           ## Verify required tools and env vars are present
	@scripts/check-prereqs.sh

infra:           ## Terraform: staging namespace, quotas and limit ranges
	cd infra/terraform && terraform init -input=false && terraform apply

config:          ## Ansible: ConfigMaps and Secrets in both environments
	ansible-playbook infra/ansible/configure-environments.yml

chain:           ## Start the Week 10 receipt chain locally (leave this terminal open)
	cd serverless && npm install --no-audit --no-fund && npx serverless offline start --stage staging

monitoring:      ## Install Prometheus + Alertmanager and load kk-payments alert rules
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
	  -n monitoring --create-namespace -f monitoring/values.yaml --wait
	kubectl apply -f monitoring/kk-payments-alerts.yaml

test:            ## Unit tests for kk-payments
	cd app && npm ci && npm test

deploy-staging:  ## Manual staging deploy of IMAGE=docker.io/canyingi/kk-payments:<tag>
	@test -n "$(IMAGE)" || { echo "usage: make deploy-staging IMAGE=..."; exit 1; }
	scripts/deploy.sh $(NS_STAGING) $(IMAGE)

smoke-staging:   ## Smoke test staging against TAG=<version-sha>
	@test -n "$(TAG)" || { echo "usage: make smoke-staging TAG=..."; exit 1; }
	scripts/smoke-test.sh $(NS_STAGING) $(TAG)

destroy:         ## Remove the staging namespace (the production namespace is never deleted)
	cd infra/terraform && terraform destroy
