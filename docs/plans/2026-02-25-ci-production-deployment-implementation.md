# CI/CD Production Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add release-please for automated versioning, conventional commit enforcement, and a production deploy pipeline to klass-hero-live on Fly.io.

**Architecture:** release-please watches main, accumulates changes into a Release PR. Merging that PR creates a GitHub Release and dispatches the production deploy workflow. A separate workflow enforces conventional commit PR titles.

**Tech Stack:** GitHub Actions, release-please (Google), Fly.io, flyctl

**Design doc:** `docs/plans/2026-02-25-ci-production-deployment-design.md`

---

### Task 1: release-please Configuration Files

**Files:**
- Create: `release-please-config.json`
- Create: `.release-please-manifest.json`

**Context:** release-please uses two config files at the repo root. The config defines behavior (release type, changelog sections). The manifest tracks the current released version so release-please knows what to bump from.

**Step 1: Create `release-please-config.json`**

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "elixir",
  "separate-pull-requests": false,
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": true,
  "include-component-in-tag": false,
  "pull-request-title-pattern": "chore: release ${version}",
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "perf", "section": "Performance Improvements" },
    { "type": "refactor", "section": "Code Refactoring" },
    { "type": "deps", "section": "Dependencies" },
    { "type": "chore", "section": "Miscellaneous", "hidden": true },
    { "type": "docs", "section": "Documentation", "hidden": true },
    { "type": "style", "section": "Styles", "hidden": true },
    { "type": "test", "section": "Tests", "hidden": true },
    { "type": "ci", "section": "CI", "hidden": true }
  ],
  "packages": {
    ".": {}
  }
}
```

Key choices:
- `bump-minor-pre-major: true` — while pre-1.0, `feat:` bumps minor (0.1.0 -> 0.2.0), not major
- `bump-patch-for-minor-pre-major: true` — `fix:` bumps patch as expected
- `hidden: true` on chore/docs/style/test/ci — these don't appear in CHANGELOG but still count toward the release
- `include-component-in-tag: false` — tags will be `v0.2.0`, not `v0.2.0-klass-hero`

**Step 2: Create `.release-please-manifest.json`**

```json
{
  ".": "0.1.0"
}
```

This must match the current `version: "0.1.0"` in `mix.exs`. release-please reads this to know the baseline.

**Step 3: Commit**

```bash
git add release-please-config.json .release-please-manifest.json
git commit -m "ci: add release-please configuration"
```

---

### Task 2: Conventional Commits Enforcement Workflow

**Files:**
- Create: `.github/workflows/conventional-commits.yml`

**Context:** release-please parses conventional commit messages on main to determine version bumps and changelog entries. Since PRs are squash-merged, the PR title becomes the commit message. This workflow validates PR titles match the format.

**Step 1: Create `.github/workflows/conventional-commits.yml`**

```yaml
name: Conventional Commits

on:
  pull_request:
    types: [opened, edited, synchronize, reopened]

permissions:
  pull-requests: read

jobs:
  validate:
    name: Validate PR Title
    runs-on: ubuntu-latest
    steps:
      # amannn/action-semantic-pull-request@v5.5.3
      - name: Check PR title follows Conventional Commits
        uses: amannn/action-semantic-pull-request@e32d7e603df1aa1ba07e981f2a23455dee596825
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          types: |
            feat
            fix
            perf
            refactor
            deps
            chore
            docs
            style
            test
            ci
            build
            revert
          requireScope: false
          subjectPattern: ^.+$
          subjectPatternError: "PR title must have a description after the type prefix"
```

Key choices:
- `requireScope: false` — scopes like `feat(enrollment):` are optional, not required
- `types` list matches the changelog-sections in release-please config
- Triggers on `synchronize` too so re-pushes re-validate

**Step 2: Verify YAML is valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/conventional-commits.yml'))" && echo "Valid YAML"
```

Expected: `Valid YAML`

**Step 3: Commit**

```bash
git add .github/workflows/conventional-commits.yml
git commit -m "ci: add conventional commits PR title enforcement"
```

---

### Task 3: release-please Workflow

**Files:**
- Create: `.github/workflows/release-please.yml`

**Context:** This workflow runs on every push to main. It either updates/creates a Release PR (accumulating changes) or, when the Release PR is merged, creates a GitHub Release and dispatches the production deploy. Uses the workflow_dispatch bridge pattern to avoid needing a PAT.

**Step 1: Create `.github/workflows/release-please.yml`**

```yaml
# Automated release management via release-please
# Creates/updates a Release PR on each push to main.
# When the Release PR is merged, creates a GitHub Release and dispatches production deploy.

name: Release Please

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write
  actions: write

jobs:
  release-please:
    name: Manage Release
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
      version: ${{ steps.release.outputs.version }}
    steps:
      # googleapis/release-please-action@v4.2.0
      - name: Run release-please
        id: release
        uses: googleapis/release-please-action@16a9c90856f42705d54a6fda1823352bdc62cf38
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      # Trigger: release-please created a new release (Release PR was merged)
      # Why: GITHUB_TOKEN events don't trigger other workflows, so we bridge
      #      via workflow_dispatch to keep workflows cleanly separated
      # Outcome: deploy-production.yml runs against the release tag
      - name: Dispatch production deploy
        if: steps.release.outputs.release_created == 'true'
        uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea # v7.0.1
        with:
          script: |
            await github.rest.actions.createWorkflowDispatch({
              owner: context.repo.owner,
              repo: context.repo.repo,
              workflow_id: 'deploy-production.yml',
              ref: '${{ steps.release.outputs.tag_name }}',
            });
            console.log(`Dispatched production deploy for ${context.payload.repository.full_name}@${{ steps.release.outputs.tag_name }}`);
```

Key choices:
- `actions: write` permission needed for `createWorkflowDispatch`
- Reuses already-pinned `actions/github-script` SHA from `pr-automation.yml`
- `ref` points to the tag so production deploys from the exact tagged commit
- release-please-action reads `release-please-config.json` and `.release-please-manifest.json` automatically

**Step 2: Verify YAML is valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release-please.yml'))" && echo "Valid YAML"
```

Expected: `Valid YAML`

**Step 3: Commit**

```bash
git add .github/workflows/release-please.yml
git commit -m "ci: add release-please workflow for automated release management"
```

---

### Task 4: Production Fly.io Configuration

**Files:**
- Create: `fly.production.toml`

**Context:** Separate Fly.io config for the production app. Mirrors dev config but targets `klass-hero-live` with `min_machines_running = 1` to avoid cold starts.

**Step 1: Create `fly.production.toml`**

```toml
# Fly.io configuration for Klass Hero LIVE (production) environment
app = "klass-hero-live"
primary_region = "fra"
kill_signal = "SIGTERM"

[build]

[deploy]
  release_command = "/app/bin/migrate"

[env]
  PHX_SERVER = "true"
  PHX_HOST = "klass-hero-live.fly.dev"
  POOL_SIZE = "10"

[http_service]
  internal_port = 4000
  force_https = true
  auto_stop_machines = "suspend"
  auto_start_machines = true
  min_machines_running = 1
  processes = ["app"]

  [http_service.concurrency]
    type = "connections"
    hard_limit = 1000
    soft_limit = 1000

  [[http_service.checks]]
    grace_period = "30s"
    interval = "30s"
    method = "GET"
    timeout = "5s"
    path = "/health"

[[vm]]
  memory = "1gb"
  cpu_kind = "shared"
  cpus = 1
```

Only differences from `fly.toml` (dev):
- `app = "klass-hero-live"` (was `klass-hero-dev`)
- `PHX_HOST = "klass-hero-live.fly.dev"` (was `klass-hero-dev.fly.dev`)
- `min_machines_running = 1` (was `0`)

**Step 2: Commit**

```bash
git add fly.production.toml
git commit -m "ci: add production Fly.io configuration for klass-hero-live"
```

---

### Task 5: Production Deploy Workflow

**Files:**
- Create: `.github/workflows/deploy-production.yml`

**Context:** Triggered by release-please via workflow_dispatch (primary path) or manually publishing a GitHub Release (fallback). Deploys to Fly.io using the production config.

**Step 1: Create `.github/workflows/deploy-production.yml`**

```yaml
# Deploy to production (klass-hero-live) on Fly.io
# Primary trigger: workflow_dispatch from release-please after Release PR merge
# Fallback trigger: manually publishing a GitHub Release

name: Deploy Production

on:
  workflow_dispatch:
  release:
    types: [published]

jobs:
  deploy:
    name: Deploy to production
    runs-on: ubuntu-latest
    concurrency: deploy-klass-hero-live
    environment:
      name: live
      url: https://klass-hero-live.fly.dev
    steps:
      # actions/checkout@v6.0.2
      - name: Checkout code
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd

      # superfly/flyctl-actions/setup-flyctl@v1.5
      - name: Set up flyctl
        uses: superfly/flyctl-actions/setup-flyctl@fc53c09e1bc3be6f54706524e3b82c4f462f77be

      - name: Deploy to Fly.io
        run: flyctl deploy --remote-only --config fly.production.toml
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN_PROD }}
```

Key choices:
- `--config fly.production.toml` targets the production app
- `FLY_API_TOKEN_PROD` — separate secret from dev's `FLY_API_TOKEN`
- `concurrency: deploy-klass-hero-live` prevents overlapping deploys
- `environment: live` links to GitHub environment for deploy history and protection rules
- Both `workflow_dispatch` and `release: [published]` triggers for flexibility

**Step 2: Verify YAML is valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy-production.yml'))" && echo "Valid YAML"
```

Expected: `Valid YAML`

**Step 3: Commit**

```bash
git add .github/workflows/deploy-production.yml
git commit -m "ci: add production deploy workflow for klass-hero-live"
```

---

### Task 6: Final Verification

**Step 1: Verify all new files exist**

```bash
ls -la release-please-config.json .release-please-manifest.json fly.production.toml
ls -la .github/workflows/release-please.yml .github/workflows/deploy-production.yml .github/workflows/conventional-commits.yml
```

Expected: all 6 files listed.

**Step 2: Verify existing workflows are untouched**

```bash
git diff .github/workflows/ci.yml .github/workflows/fly-deploy.yml .github/workflows/security.yml .github/workflows/pr-automation.yml
```

Expected: no output (no changes).

**Step 3: Verify all YAML files parse**

```bash
for f in .github/workflows/*.yml; do
  python3 -c "import yaml; yaml.safe_load(open('$f'))" && echo "OK: $f" || echo "FAIL: $f"
done
```

Expected: `OK` for every workflow file.

**Step 4: Review full git log for this branch**

```bash
git log --oneline main..HEAD
```

Expected: 5 commits (design doc + 4 implementation commits from tasks 1-5).

---

## Manual Prerequisites Checklist

These steps must be done by the user outside of this plan:

1. **Fly.io:** `flyctl apps create klass-hero-live` and set up production database + secrets
2. **GitHub Secret:** Add `FLY_API_TOKEN_PROD` to repo secrets
3. **GitHub Environment:** Create `live` environment in repo Settings > Environments
4. **GitHub Actions Permissions:** Enable "Allow GitHub Actions to create and approve pull requests" in Settings > Actions > General
