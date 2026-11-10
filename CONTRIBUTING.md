# How to contribute

These are the rules I follow in this repo. Following them keeps the history easy to read, for me and for anyone who picks this project up after me.

## Branches
- Nothing goes straight into `main`. GitHub blocks direct pushes, and I tested that it does. Every change comes in through a pull request.
- Merging to `main` deploys to staging automatically, so `main` should always be in a working state.
- Branch names start with the kind of change: `feat/`, `fix/`, `docs/`, `chore/`, `ci/` or `test/`, then a short topic, for example `feat/infra-staging`.

## Commit messages
I use the Conventional Commits format, which I learned about during this course:

```
<type>(<scope>): <short summary in the imperative, max 72 characters>

<optional: WHY I made this change — the diff already shows what changed>

Refs: #<issue number>
```

**Types:** `feat` (new feature), `fix` (bug fix), `docs`, `test`, `ci` (pipeline), `build` (Dockerfile or packaging), `chore` (housekeeping), `refactor`, `perf`, `revert`.
**Scopes I use:** `infra`, `config`, `k8s`, `app`, `pipeline`, `monitoring`, `serverless`, `docs`.

Good: `feat(pipeline): only offer production approval after the staging smoke test passes`
Not OK: `fix`, `update`, `wip`, `changes`, `final`. In earlier weeks I wrote messages like these, and later I couldn't tell what each commit did.

To close a GitHub Issue from a commit, put `Fixes #12` in the commit body. GitHub closes the issue when the commit reaches `main`.

## Pull requests
- Merge with **Rebase and merge** only. It keeps every commit as I wrote it and avoids "Merge pull request" commits, which don't follow the format above.
- Fill in the PR template: what changed, why, how I tested it, and what could go wrong.

## Releases
I use annotated tags, so each release has a message and a date:
`git tag -a v1.0.0 -m "<what this release contains>" && git push origin v1.0.0`
