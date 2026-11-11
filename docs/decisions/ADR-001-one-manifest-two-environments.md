# ADR-001: One Deployment file for staging and production

**Status:** Accepted · **Date:** 10 Nov 2026

## The problem
Track A says staging and production must use **the same Deployment manifest**, with different settings (for example `DB_HOST`). If the two files are allowed to differ, staging stops being a real test: a change can pass in staging only because staging's file is different.

## Options I considered
| Option | Good | Bad |
|---|---|---|
| A. Two copies of the file | Easy to read | They drift apart. A probe added to one gets forgotten in the other |
| B. Kustomize base + overlays | Common in industry | An overlay can change anything (replicas, probes, image), so "the same manifest" depends on people being careful. One more tool to learn |
| C. Helm chart with values per environment | Powerful | Same weakness as B, and heavy for one service |
| **D. One file with no namespace and no environment values. Namespace from `kubectl apply -n`, settings from the ConfigMap, the image tag swapped in by the pipeline** | The file is **identical** in both environments, and anyone can check that with `git log k8s/` | Only the image line is swapped, and `sed` is cruder than a templating tool. I can't give staging a different *structure* (for example 1 replica) |

## Decision
**D.** The restriction is the point. If staging ever needs a structurally different Deployment, I want that to be an argument in a PR, not something hidden in an overlay.

## What it cost me
- Staging runs 2 replicas like production: a bit more CPU, but it tests the same rolling-update behaviour. That's how I found the `minReadySeconds` problem in staging, not production.
- Changing a ConfigMap does not restart pods on its own; I run `kubectl rollout restart` (it's in the runbook). Second pass: add a config-hash annotation.
- The ConfigMap name `kk-payments-config` is written in two places (the Ansible playbook and the Deployment). The course guide warns this seam breaks easily. `scripts/deploy.sh` checks the ConfigMap exists before deploying, so a mismatch fails clearly instead of giving `CreateContainerConfigError`.
