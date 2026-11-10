## What I changed
<!-- one or two sentences -->

## Why
<!-- the problem this solves. Link the issue: Fixes #__ -->

## How I tested it
- [ ] `make test` passes
- [ ] Deployed to staging and `scripts/smoke-test.sh kijani-staging <tag>` passed
- [ ] Other:

## What could go wrong
<!-- What might break? How would I notice? How would I undo it? -->

## Before merging
- [ ] No passwords, tokens or kubeconfig in the diff (`git diff --cached | grep -iE 'token|password|secret'`)
- [ ] README / runbook / decision records updated if behaviour changed
- [ ] If an AI tool helped write any of this, I added an entry to `docs/ai-governance-log.md`
