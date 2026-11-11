# ADR-003: Jenkins polls GitHub every 2 minutes instead of using a webhook

**Status:** Accepted · **Date:** 10 Nov 2026

## The problem
"A merge to main triggers the pipeline with no manual steps." Jenkins runs on my laptop, behind my home network. A GitHub webhook needs a public URL to call.

## Options
| Option | Delay | Exposure | Effort |
|---|---|---|---|
| Webhook through a tunnel (ngrok / smee.io) | Seconds | My laptop's Jenkins, which holds Docker Hub and cluster credentials, becomes reachable from the internet; the tunnel URL changes on every restart | Medium, and fragile in a live demo |
| **`pollSCM('H/2 * * * *')`** | Up to 2 min | **Nothing inbound**: Jenkins only makes outgoing git fetches | Low |
| GitHub Actions self-hosted runner that calls Jenkins | Seconds | A runner token on the laptop | High: a second CI system |

## Decision
Polling. Two minutes costs nothing at a few merges a day. Opening a CI server that holds credentials to the internet is a real risk.

## What happened in practice
- Measured: PR #14 merged at 13:17:25, build #7 started itself at 13:19:12, a delay of **1 min 47 s** (success criterion S2).
- Lesson: polling only works while the laptop is awake. A merge just before the laptop slept was never built. Known gap in README §7.
- Second pass: move Jenkins to a server behind an authenticated ingress and switch to a webhook.
