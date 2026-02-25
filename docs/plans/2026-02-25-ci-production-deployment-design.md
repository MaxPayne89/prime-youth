# CI/CD Pipeline Extension for Production Deployments

## Problem

Dev deploys happen automatically on merge to main, but there is no production deployment pipeline. As we approach go-live, we need a controlled release process with automated versioning and manual deploy gates.

## Decision

Use Google's **release-please** for automated release management with a PR-based manual gate, combined with a separate production deploy workflow triggered via workflow_dispatch bridge.

## Flow

```
PR merged to main
  -> CI runs (existing)
  -> Dev deploy (existing)
  -> release-please updates/creates Release PR
      (accumulates changes, bumps version, generates CHANGELOG)

Merge the Release PR
  -> release-please creates GitHub Release + git tag
  -> Dispatches production deploy workflow
  -> Production deploys to klass-hero-live (live environment)
```

## New/Modified Files

### `.github/workflows/release-please.yml` (new)

- Triggers: push to main
- Runs `googleapis/release-please-action@v4` with `release-type: elixir`
- On `release_created`: dispatches `deploy-production.yml` via `actions/github-script`
- Uses workflow_dispatch bridge pattern (no PAT needed)

### `.github/workflows/deploy-production.yml` (new)

- Triggers: `workflow_dispatch` (from release-please) + `release: [published]` (manual fallback)
- Deploys to Fly.io using `FLY_API_TOKEN_PROD` secret
- GitHub environment: `live`, URL: `https://klass-hero-live.fly.dev`
- Concurrency lock: `deploy-klass-hero-live`
- Uses `--config fly.production.toml`

### `.github/workflows/conventional-commits.yml` (new)

- Triggers: PR open/edit/sync
- Validates PR title follows Conventional Commits format
- Uses `amannn/action-semantic-pull-request`

### `fly.production.toml` (new)

- `app = "klass-hero-live"`
- `PHX_HOST = "klass-hero-live.fly.dev"`
- `min_machines_running = 1` (always warm, no cold starts)
- Same region (`fra`), same VM specs as dev

### `release-please-config.json` + `.release-please-manifest.json` (new)

- Config: `release-type: elixir`, changelog sections for feat/fix/perf/deps
- Manifest: `{ ".": "0.1.0" }` (matches current mix.exs)
- `bump-minor-pre-major: true` (pre-1.0 safe versioning)

### `.github/workflows/fly-deploy.yml` (unchanged)

Dev deploy continues as-is: main -> CI pass -> auto-deploy to klass-hero-dev.

## Unchanged Workflows

- `ci.yml` -- untouched
- `security.yml` -- untouched
- `pr-automation.yml` -- untouched

## Prerequisites (manual)

1. Create `klass-hero-live` app on Fly.io
2. Set up production database and secrets on Fly.io
3. Add `FLY_API_TOKEN_PROD` secret to GitHub repo
4. Create `live` GitHub environment in repo settings
5. Enable "Allow GitHub Actions to create and approve pull requests" in Settings > Actions > General
