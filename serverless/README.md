# serverless/: the receipt chain

This is my Week 10 receipt chain, extended so that kk-payments running in Kubernetes can start it.
It runs on my laptop with `serverless-offline` (which runs the functions) and `serverless-s3-local`
(a small S3 server on port 4569 that fires bucket events).

## How a receipt moves through the chain

```
kk-payments pod (kijani-staging)  ─┐
                                   ├─ receipt-<orderId>.json ─►  kk-payments-receipts-staging
curl POST :3005/staging/receipts ──┘                                    │  (S3 event)
                                                                         ▼
                                                    processReceiptUpload  (kk-processor)
                                                                         │ processed-<orderId>.json
                                                                         ▼
                                                    kk-receipts-processed-staging
                                                                         │  (S3 event)
                                                                         ▼
                                                    notifyReceipt  (kk-notifier)
                                                                         │ notify-<orderId>.json
                                                                         ▼
                                                    kk-notifications-queue-staging
```

Every function writes one structured JSON log line with the same `orderId`, so one payment can be followed through all three.

## Run it

```bash
make chain            # same as: cd serverless && npm install && npx serverless offline start --stage staging
```

Leave that terminal open. You should see `S3 local started ( port:4569 ... address: 0.0.0.0 )`.

Test it on its own with one curl, which should produce three log lines:

```bash
curl -X POST http://localhost:3005/staging/receipts \
  -H "Content-Type: application/json" -d '{"orderId":"ORD-CHAIN-001","amount":7500,"currency":"KES"}'
```

## Things I had to work out

- **The S3 server must listen on `0.0.0.0`, not `localhost`.** By default it only accepts connections from the laptop itself, so pods inside Minikube could not reach it. Setting `custom.s3.address: 0.0.0.0` fixed that. Pods reach the laptop as `host.minikube.internal:4569`.
- **Bucket events only fire inside serverless-s3-local.** My first plan was for Terraform to create the receipt buckets in MinIO. A file written to MinIO would never trigger these functions, though, so the buckets now live here. See `docs/decisions/ADR-004-receipt-buckets-live-with-the-chain.md`.
- **My firewall blocked the pods.** Minikube runs as a VirtualBox VM (`192.168.59.103`), and my laptop is `192.168.59.1` on `vboxnet0`. My Week 3 `ufw` setup only allows SSH, so pods timed out on port 4569. I did not turn the firewall off. I allowed only that port, only from the Minikube network:
  `sudo ufw allow in on vboxnet0 from 192.168.59.0/24 to any port 4569 proto tcp comment 'Minikube pods -> receipt chain (S3 local)'`
- **Serverless Framework v3, not v4.** v4 asks you to log in to a Serverless account even for local use. v3 runs fully offline, which fits my no-cloud-account setup.
- **A badly named file does not crash the processor.** A key like `receipt-.json` is logged as `receipt.skipped` with a warning (the edge case from the Week 10 lab).

## What is not covered (known gaps)

- Production kk-payments writes to `kk-payments-receipts`, but no chain runs for production. Track A only asks for staging.
- If a function crashes, the S3 event is lost and nothing retries it. In AWS I would add a dead-letter queue (SQS) so failed events are kept and can be replayed. This is the Week 10 lab analysis question.
