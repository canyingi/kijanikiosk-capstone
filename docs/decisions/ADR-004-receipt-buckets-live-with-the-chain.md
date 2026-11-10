# ADR-004: The receipt buckets belong to the serverless stack, not Terraform

**Status:** Accepted · **Date:** 10 Nov 2026 · **Replaces:** my original plan in scope v1.0

## What I first planned
My scope said Terraform would create the two receipt buckets in MinIO, because MinIO already holds my Terraform state and I wanted all the infrastructure in one place.

## What I found out
When I looked again at my Week 10 labs, I saw that the receipt chain gets its bucket events from **serverless-s3-local**, a separate S3 server that runs inside `serverless offline` on port 4569. MinIO knows nothing about my Lambda functions. If kk-payments wrote a receipt to a MinIO bucket, the file would be saved, but **no function would ever run**. The chain would look fine and silently do nothing.

## Options I looked at
| Option | Good | Bad |
|---|---|---|
| A. Keep the buckets in MinIO (Terraform) and send MinIO bucket notifications to the functions with a webhook | All buckets created by Terraform | Extra moving parts (webhook format, offline invoke endpoint). Hard to debug, and nothing in the course covered it |
| **B. Declare the buckets in `serverless.yml` and let kk-payments write to serverless-s3-local** | Bucket and trigger are defined together, so they can't drift apart. Same setup as my Week 10 lab. Tested end to end | Terraform no longer owns every piece of infrastructure. The S3 server only runs while `make chain` is running |
| C. LocalStack | Closer to real AWS | Another big container on an already busy laptop |

## Decision
Option B. A bucket whose job is to trigger a function should be defined in the same place as that function. Terraform still owns the namespaces, quotas and limit ranges, which last longer and which other things depend on.

## What this costs me
- `make chain` has to be running for staging payments to work. The pipeline's Preflight stage checks this and fails with a clear message if it isn't.
- serverless-s3-local only accepts the fixed credentials `S3RVER`/`S3RVER`. I still pass them through the `kk-payments-secrets` Secret, so the Deployment would work the same way with real AWS keys.
- In real AWS, the same `serverless.yml` would create real S3 buckets with real event notifications. No change to kk-payments would be needed apart from removing `S3_ENDPOINT`.
