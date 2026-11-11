# Peer Review Test Plan

**Written on:** 11 Nov 2026, before the peer session. The commit date of this file is the proof.
**Reviewer:** _(classmate's name)_ · **Author:** Victor Kanyingi · **Commit tested:** _(fill in on the day: `git rev-parse --short HEAD`)_

## How the session works
- The reviewer follows **only the README**. I stay quiet and don't explain anything.
- Every time the reviewer has to ask me something, I open a GitHub Issue for it, because it means the README didn't answer the question.
- 60 minutes maximum. If the reviewer hits something they can't get past, we log it and stop that test.

## What the reviewer checks
| ID | Reviewer does | Expected | Success criterion |
|---|---|---|---|
| T1 | Fresh clone, follow README §3 to §4.4 | `kijani-staging` exists; a second `terraform plan` says No changes | S1 |
| T2 | `make config`, then read both ConfigMaps | `DB_HOST` is different; no secret value is in the repo | S4 |
| T3 | Open a small PR and merge it, then don't touch Jenkins | A build starts by itself within 3 minutes (`Started by an SCM change`) | S2 |
| T4 | Watch that build | *Approve Production* only appears after *Smoke Test Staging* is green | S3 |
| T5 | Approve with an empty reason; then rerun and approve with a real one | Empty is refused; the real reason shows in `approval-record.json` and on the Deployment | S3 |
| T6 | Merge the prepared broken branch `demo/broken-payments` | Staging smoke test fails, staging is rolled back, production keeps its version | S5 |
| T7 | `scripts/inject-fault.sh kijani-staging crash` | `KkPaymentsPodRestarting` is firing within 5 minutes | S5 |
| T8 | One staging payment | `kk-processor` and `kk-notifier` log the same `orderId` within 30 seconds | S6 |
| T9 | Reviewer's choice: try to break something | Whatever happens gets logged | none |

## Severity
- **High:** blocks a success criterion, or is a security problem (a secret exposed, a deploy to the wrong environment)
- **Medium:** it works, but only with knowledge that isn't in the README
- **Low:** wording, naming, looks
