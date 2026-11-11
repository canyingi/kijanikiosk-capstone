# ADR-002: Terraform creates, Ansible configures, Jenkins deploys

**Status:** Accepted · **Date:** 10 Nov 2026

## The problem
Terraform and Ansible can both create namespaces *and* ConfigMaps. If both tools manage the same object, each run undoes the other, and nobody knows which one is the truth.

## Decision
| Object | Owner | Why |
|---|---|---|
| Namespace, ResourceQuota, LimitRange | **Terraform** | They exist for a long time and other things depend on them. `terraform plan` shows me what would change before it changes |
| ConfigMaps, Secrets | **Ansible** | They change more often. Secret values come from `.env` when the playbook runs, so they **never enter Terraform state** (which is plain JSON in MinIO) |
| Deployment, Service | **Jenkins** (`scripts/deploy.sh`) | They change on every release and have to be tied to a build and an approval |

Ansible only *checks* that the namespace exists. It never creates it.

## Trade-off I accepted
Two tools instead of one. The deciding reason was keeping the Docker Hub token and app secrets out of `terraform.tfstate`.

## What it cost me
- Setup order is fixed: `make infra` → `make config` → pipeline. The README and `deploy.sh` enforce it.
- Renaming a namespace means editing `infra/terraform/variables.tf` **and** `infra/ansible/vars/environments.yml`. Second pass: generate the Ansible vars from `terraform output -json`.
