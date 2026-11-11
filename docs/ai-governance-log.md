# AI Governance Log

Every time AI tooling produced code, configuration or analysis that ended up in this project, I logged it here using the Week 10 eight-field format. I used AI as a working partner, not as an authority. Every entry says what it got wrong, because in each case something *was* wrong, and I usually only found out by running it.

**Week 10 governance checklist (six controls):**
1. **C1 Least privilege**: every permission is scoped to the minimum required
2. **C2 Encryption at rest and in transit**
3. **C3 No hardcoded secrets**
4. **C4 Naming and tagging conventions**
5. **C5 Auditability and logging**
6. **C6 Data classification and residency**

The full review of my own AI-generated system against all six controls is at the end of this file.

---

## Entry 1: AI-generated infrastructure and pipeline code (Track A starter kit)

| # | Field | Entry |
|---|---|---|
| 1 | Date | 10 Nov 2026 (used and corrected through 11 Nov 2026) |
| 2 | Tool used | Claude (claude.ai) |
| 3 | Task description | Turn my Week 4–10 work into a Track A system: a Terraform staging namespace, Ansible per-environment config, one shared Kubernetes Deployment, a Jenkinsfile with a staging smoke test and production approval gate, and Prometheus alert rules. |
| 4 | What was provided to the AI | The capstone rubric, the Track A requirements, my GitHub repo `canyingi/kijanikiosk` (Weeks 3–8), and later my Week 9 and Week 10 lab briefs. |
| 5 | What the AI produced | A starter kit: `infra/terraform`, `infra/ansible`, `k8s/` (one Deployment for both namespaces), `Jenkinsfile`, `scripts/deploy.sh` and `smoke-test.sh`, `monitoring/` alert rules and Helm values, plus decision records ADR-001 to ADR-004. |
| 6 | What it got right | Keeping a single Deployment file, with environment differences only in ConfigMaps. Writing the approval reason with `jq --arg`, so free text can't run as a shell command. Only offering the production gate after the staging smoke test passes. Rolling back after a failed run. Keeping secret values out of Terraform state by giving them to Ansible. |
| 7 | What it got wrong | **(a)** The Jenkins apt key was the old 2023 key, and `apt update` failed with `NO_PUBKEY 7198F4B714ABFC68`. **(b)** The Lint & Test stage mounted the workspace with `docker run -v`; my snap Docker daemon can't see `/var/lib/jenkins`, so pipeline run #1 failed with `read-only file system`. **(c)** It assumed `maxUnavailable: 0` would keep staging up during a bad release. My crash test took *both* staging pods down, because pods passed readiness at about 3 s and crashed at 5 s. **(d)** The full kube-prometheus-stack it suggested was far too big for my 7 GB laptop, and the Minikube VM was killed (`aborted`). **(e)** The first plan put the receipt buckets in Terraform/MinIO, where bucket events would never trigger my functions. **(f)** A `values.yaml` edit it gave me appended duplicate YAML keys, which silently removed the `prometheusSpec` settings. |
| 8 | What I changed before applying the output | (a) Switched to the 2026 key after checking the Jenkins blog. (b) Changed the test stage to stream the code in with `tar \| docker run -i`, with no mount (commit `fix(pipeline): stream app code...`). (c) Added `minReadySeconds: 15` (PR #16). In a re-test, the 2 old pods stayed `Running` and `AVAILABLE` stayed 2 while the bad pod crash-looped. (d) Cut the monitoring stack down: default rules, node-exporter and control-plane scraping off, Prometheus capped at 768 Mi, NodePorts instead of port-forward. Also capped Jenkins at `-Xmx768m`. (e) Moved the buckets into `serverless.yml` (ADR-004). (f) Restored `values.yaml` from the kit and merged with Python instead of appending. Not all of these were caught *before* applying. (a), (b), (c) and (d) were only caught when I ran them, which is why everything now goes through staging first. |

**Checklist controls applied:** **C3 No hardcoded secrets**: confirmed with `git grep` that no secret is committed, Ansible uses `no_log: true`, and values come from a git-ignored `.env`. **C1 Least privilege**: the firewall rule for pods only opens TCP 4569, only from `192.168.59.0/24`, only on `vboxnet0`. **C6 Data residency**: found that the generated `serverless.yml` uses `region: us-east-1` (see the review table below).

---

## Entry 2: AI-assisted log analysis during an incident (pods couldn't save receipts)

| # | Field | Entry |
|---|---|---|
| 1 | Date | 10 Nov 2026 (about 23:55) |
| 2 | Tool used | Claude (claude.ai) |
| 3 | Task description | Find out why `POST /payments` returned **500** from staging pods, when the same code worked from my laptop. |
| 4 | What was provided to the AI | The smoke test output (`POST /payments -> 500`), then the pod's structured JSON error log line: `"msg":"unhandled error","route":"/payments","error":"The specified bucket does not exist"`. Also the ConfigMap values (`S3_ENDPOINT=http://host.minikube.internal:4569`, `RECEIPTS_BUCKET=kk-payments-receipts-staging`). |
| 5 | What the AI produced | A hypothesis that the local S3 server (s3rver) treats the request's **host name** as a bucket name ("virtual-host" buckets), so a request to `host.minikube.internal` looks for a bucket called `host.minikube.internal`. A test sending the same request with three different `Host` headers. The fix: `vhostBuckets: false` in `serverless.yml`. |
| 6 | What it got right | The root cause, shown by the test: `Host: localhost` → 200, `Host: host.minikube.internal` → `NoSuchBucket` with `<BucketName>host.minikube.internal</BucketName>`, and with `vhostBuckets: false` → 200. After the change, the staging smoke test passed and the receipt chain finished in 1 s. |
| 7 | What it got wrong | **About an hour earlier, a test pod got `404` reading a receipt file, and the AI told me the file had "probably been deleted, so the network path must be fine".** That was wrong: it was this same bug. I accepted that explanation and moved on, so I lost time. The first suggested fix for the `000`/timeout before that (check DNS, change the endpoint) also missed the real cause, which was my **ufw firewall** from Week 3. I found that myself with `sudo ufw status`. |
| 8 | What I changed before applying the output | I didn't accept the `vhostBuckets` explanation until I'd seen the Host-header test results myself. I added the setting with a comment saying why, and the commit message records the misdiagnosis honestly. For the firewall, I refused to turn ufw off. I added a narrow rule (TCP 4569, Minikube network only, `vboxnet0` only) and documented it in the README so a new engineer doesn't hit the same wall. |

**Checklist controls applied:** **C1 Least privilege**: the narrow ufw rule, not "disable the firewall". **C5 Auditability and logging**: the root cause was only findable because kk-payments logs structured JSON with the real S3 error message in it.

---

## Entry 3: AI-suggested setup commands for MinIO credentials

| # | Field | Entry |
|---|---|---|
| 1 | Date | 10 Nov 2026 (about 22:00–22:30) |
| 2 | Tool used | Claude (claude.ai) |
| 3 | Task description | Start a MinIO container for Terraform state, with my own username and password from `.env` instead of the default login. |
| 4 | What was provided to the AI | My Week 4 MinIO setup (the `pgsty/minio` image) and the Terraform S3 backend error `InvalidAccessKeyId`. |
| 5 | What the AI produced | A `docker run` command passing `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `.env`, editing `.env` in `nano`, and later a "guard" line meant to stop the commands if the values were empty. |
| 6 | What it got right | Diagnosing that MinIO wasn't using my `.env` values at all, by testing whether the default `minioadmin` login worked (it did). The final fix: fill `.env` with `sed`, check each value's length isn't 0, then recreate the container. |
| 7 | What it got wrong | **My first MinIO ran on the default `minioadmin/minioadmin` login without anyone noticing.** My `nano` edits weren't saved, so the variables were empty. Docker passed empty values, and MinIO fell back to its default password. The AI's first guess was that the `pgsty/minio` image ignored the settings, which was wrong, since the image's docs say it uses the same `MINIO_*` variables. The "guard" line it gave me (`: "${VAR:?}"`) printed an error but **did not stop** the pasted block, so MinIO was recreated with empty credentials a second time. |
| 8 | What I changed before applying the output | I filled `.env` with `sed` instead of an editor, and I now check `${#AWS_ACCESS_KEY_ID}` before any `docker run`. I added that check to the README (section 4.1), with a note on why. I recreated the MinIO data folder so nothing from the default-login period was kept. |

**Checklist controls applied:** **C3 No hardcoded secrets**: no default credentials in use, secrets only in a git-ignored `.env`, and lengths checked without printing the values.

---

## Governance review: my AI-generated system against the six controls

I applied the Week 10 checklist to the code the AI generated for this project, as it is actually deployed, not to a mock. It is not all passes. Some gaps are acceptable for a laptop project, and I say which.

| Control | Result | Finding | Remediation |
|---|---|---|---|
| **C1 Least privilege** | **Fail** | (a) The Jenkins `input` step has no `submitter`, so *any* logged-in Jenkins user can approve a production release. (b) Jenkins uses the Minikube **admin** kubeconfig, so it can change any namespace, not just the two it deploys to. | (a) Add `submitter: 'canyingi'` to the `input(...)` call in the *Approve Production* stage. (b) Second pass: a `jenkins-deployer` ServiceAccount with a namespaced `Role` (deployments and services only) in `kijani-staging` and `default`, and a kubeconfig built from that token. |
| **C2 Encryption at rest and in transit** | **Fail (accepted locally)** | kk-payments writes receipts to serverless-s3-local over plain `http://host.minikube.internal:4569`. The buckets have no server-side encryption. MinIO (Terraform state), Prometheus and Alertmanager are all plain HTTP. | In AWS: add `BucketEncryption` with `SSEAlgorithm: aws:kms` to each bucket in `serverless.yml` `resources`, and remove `S3_ENDPOINT` so the SDK uses HTTPS. Locally: accepted, because it's single-machine traffic on a host-only network. Listed in README §7. |
| **C3 No hardcoded secrets** | **Pass, with a note** | Secrets come from `.env` (git-ignored) through Ansible with `no_log: true`; `git grep` finds no real secret. The only committed credentials are serverless-s3-local's fixed public dev values (`S3RVER`), commented as such. Jenkins's `docker login` warns that it stores credentials unencrypted, but the pipeline runs `docker logout` straight after the push. | Keep `docker logout`. In a real environment, use a Docker credential helper on the Jenkins host, and External Secrets / Vault instead of Ansible-written Secrets. |
| **C4 Naming and tagging** | **Partial** | Names are consistent (`kk-payments-*`, `kijani-staging`, `kk-*-staging` buckets). The namespace has `environment` and `managed-by` labels. But the Deployment has no `owner` or cost-centre label, and the receipt buckets have no tags. | Add `kijanikiosk.io/owner: payments-team` and `kijanikiosk.io/cost-centre: payments` labels to `k8s/kk-payments-deployment.yaml` metadata, and `Tags` to each bucket in `serverless.yml`. |
| **C5 Auditability and logging** | **Pass, with a gap** | Each release records approver, reason, build and image in `approval-record.json` and as annotations on the Deployment. Every request is logged as structured JSON, and alerts reach Alertmanager. **Gap:** Jenkins keeps only the last 20 builds (`logRotator(numToKeepStr: '20')`), so older approval records are deleted. | Copy `approval-record.json` to a MinIO bucket (or commit it to an `audit` branch) in the *Deploy to Production* stage, so the audit trail outlives Jenkins's build retention. |
| **C6 Data classification and residency** | **Fail** | `serverless.yml` has `region: us-east-1`, and kk-payments defaults `AWS_REGION` to `us-east-1`, the AI's default region. Receipts contain **payment data for East African customers**. Deployed as-is, they would be stored in the USA. | Set `provider.region: af-south-1` (Cape Town, the nearest AWS region to Kenya) in `serverless.yml`, and `AWS_REGION` in the ConfigMap via `vars/environments.yml`. Before any real deployment, confirm the transfer is allowed under Kenya's Data Protection Act 2019 and the Central Bank of Kenya's guidance for payment data. |

**What I fixed straight away:** C1(a), the `submitter` on the approval gate (see the commit after this one).
**What I documented as a known gap:** C1(b), C2, C4, C5 and C6, in README §7 with the remediation above.

## What I learned about using AI on this project

AI made me much faster at producing a first version, but it couldn't see my machine: snap Docker, 7 GB of RAM, a firewall from Week 3, a sleeping laptop. Almost every error in this log came from that gap. My rule now: **AI output goes through staging and a real test before I believe it**, and when the AI explains a symptom ("the file was probably deleted"), I check the explanation before moving on.
