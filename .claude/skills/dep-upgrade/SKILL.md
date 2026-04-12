---
name: dep-upgrade
description: >-
  Upgrade Hex dependencies with safety checks and changelog review.
  Detects outdated deps, classifies upgrades by semver risk, presents
  an assessment table for confirmation, then applies upgrades with
  test verification. Use when: "upgrade deps", "update dependencies",
  "check for outdated packages", or "bump phoenix". Invoke with:
  /dep-upgrade [package-name|--all]
---

# Dep-Upgrade

Upgrade Hex dependencies safely with semver classification, changelog review, and test verification.

**Type:** Rigid workflow. Follow steps exactly.

---

## Step 1: Parse Arguments

Parse `$ARGUMENTS`:

- **Empty or `--all`** — full audit of all outdated deps
- **Package name** (e.g., `phoenix`) — single-package upgrade mode
- **Multiple package names** (e.g., `phoenix ecto_sql`) — batch upgrade of listed packages

Store the mode for use in subsequent steps.

## Step 2: Detect Outdated Dependencies

Run the hex outdated check:

```bash
mix hex.outdated
```

If a specific package was requested:

```bash
mix hex.outdated <package-name>
```

Parse the output to extract for each outdated dependency:

- **Package name**
- **Current version** — what is locked in mix.lock
- **Latest version** — newest available on Hex
- **Requirement** — the version constraint in mix.exs

If no outdated dependencies are found, STOP:

```
All dependencies are up to date. Nothing to do.
```

## Step 3: Classify and Assess

For each outdated dependency, determine:

### Semver Classification

| Classification | Rule | Risk |
|---|---|---|
| `patch` | Only the patch version changed (e.g., 1.2.3 -> 1.2.5) | Low — bug fixes only |
| `minor` | Minor version changed (e.g., 1.2.3 -> 1.3.0) | Medium — new features, possible deprecations |
| `major` | Major version changed (e.g., 1.2.3 -> 2.0.0) | High — breaking changes expected |
| `pre-release` | Target is a pre-release version (rc, beta, alpha) | Variable — evaluate individually |

### Constraint Check

For each dependency, check if the current mix.exs constraint allows the latest version:

- If `~> 1.2` and latest is `1.3.0` — **constraint allows it** (just run `mix deps.update`)
- If `~> 1.2` and latest is `2.0.0` — **constraint blocks it** (mix.exs edit required)
- If `>= 0.0.0` — **constraint always allows** (just run `mix deps.update`)

### Effort Estimate

| Effort | Meaning |
|---|---|
| `trivial` | Constraint allows update; no breaking changes expected |
| `small` | Constraint needs edit; patch or minor with no deprecation warnings |
| `medium` | Minor bump with known deprecations or config changes |
| `large` | Major version bump; migration guide likely needed |

### Changelog Lookup

For each `minor` or `major` upgrade, check for breaking changes:

```bash
# Check hex.pm package page for changelog link
mix hex.info <package-name>
```

Note the repository URL from the output. If it is a GitHub repo, fetch the changelog:

```bash
# Try common changelog locations
gh api repos/{owner}/{repo}/releases/latest --jq '.body' 2>/dev/null
```

Summarize any breaking changes, deprecations, or migration steps found.

## Step 4: Present Assessment

Display the assessment for user confirmation. Use this exact format:

```markdown
# Dependency Upgrade Assessment

**Mode:** [all / single: package-name]
**Outdated:** X dependencies

## Summary

| Type | Count |
|------|-------|
| Patch | N |
| Minor | N |
| Major | N |

## Upgrades

| # | Package | Current | Latest | Type | Effort | Constraint | Notes |
|---|---------|---------|--------|------|--------|------------|-------|
| 1 | phoenix | 1.8.1 | 1.8.3 | patch | trivial | allows | Bug fixes |
| 2 | oban | 2.21.0 | 2.22.0 | minor | small | allows | New features, no breaking |
| 3 | bandit | 1.5.0 | 2.0.0 | major | large | blocks | Breaking: see migration guide |

## Recommended Approach

**Safe batch (patch + trivial minor):** #1, #2 — can upgrade together
**Individual (major/risky):** #3 — upgrade separately with careful testing
```

**STOP HERE.** Wait for user to:

1. Confirm the full plan
2. Select specific packages by number (e.g., "just do 1 and 2")
3. Exclude specific packages (e.g., "skip 3")
4. Ask for more detail on a specific package

Do NOT upgrade before user confirms.

## Step 5: Apply Upgrades — Safe Batch

For all confirmed `patch` and `trivial` minor upgrades whose constraints already allow the update:

```bash
mix deps.update <package1> <package2> <package3>
```

Then verify:

```bash
mix compile --warnings-as-errors
mix test
```

If compilation or tests fail:

1. Identify which package caused the failure
2. Revert by restoring mix.lock from git for that package and re-running `mix deps.get`
3. Report the failure and continue with remaining packages
4. Offer to file a GitHub issue for the failed upgrade

Show progress: `Batch upgrade: X packages updated, compiling...`

## Step 6: Apply Upgrades — Individual

For each confirmed upgrade that requires a mix.exs constraint change or is classified as `major`:

Process one at a time in this order: minor before major.

For each package:

1. **Read the current constraint** in mix.exs
2. **Update the constraint** to allow the new version:
   - For minor: widen the constraint (e.g., `~> 1.2` -> `~> 1.3`)
   - For major: update to new major (e.g., `~> 1.8` -> `~> 2.0`)
3. **Fetch and compile:**
   ```bash
   mix deps.get
   mix compile --warnings-as-errors
   ```
4. **Check for deprecation warnings** in the compilation output
5. **Run tests:**
   ```bash
   mix test
   ```
6. **If tests fail:**
   - Diagnose the failure
   - Apply fixes if they are straightforward (< 20 lines of changes)
   - If fixes are complex, revert the upgrade and offer to file a GitHub issue
7. **Report result** before moving to next package

Show progress: `Upgrading 2/3: oban 2.21.0 -> 2.22.0`

## Step 7: Verify and Commit

After all confirmed upgrades are applied:

```bash
mix precommit
```

If precommit fails, diagnose and fix before proceeding.

Stage and commit:

```bash
git add mix.exs mix.lock
# Also add any files modified to fix deprecations/breaking changes
git add <changed-files>
git commit -m "chore: upgrade dependencies

Upgraded:
- package1 1.0.0 -> 1.0.1 (patch)
- package2 2.1.0 -> 2.2.0 (minor)

Refs: mix hex.outdated"

git push
```

## Step 8: Summary

Present final summary:

```markdown
# Dependency Upgrade Summary

| Package | From | To | Type | Status |
|---------|------|----|------|--------|
| phoenix | 1.8.1 | 1.8.3 | patch | upgraded |
| oban | 2.21.0 | 2.22.0 | minor | upgraded |
| bandit | 1.5.0 | 2.0.0 | major | skipped — user deferred |

**Upgraded:** X packages
**Skipped:** Y packages
**Failed:** Z packages
**Commit:** [sha]
**Pushed:** yes/no
```

---

## Rules

- **Never upgrade before user confirms the assessment.** The assessment is a proposal, not a decision.
- **Always run `mix precommit` before committing.** Zero warnings, zero test failures.
- **Always push after committing.** Work is not done until pushed.
- **Patch upgrades are safe to batch.** Group them into a single `mix deps.update` call.
- **Major upgrades are always individual.** One package at a time with full test verification.
- **Revert on failure.** If an upgrade breaks tests and the fix is non-trivial, revert and report.
- **Never widen constraints unnecessarily.** Only change mix.exs when the current constraint blocks the desired version.
- **Check changelogs for minor and major.** Patch-only upgrades do not need changelog review.
- **Respect git hygiene.** Stage only mix.exs, mix.lock, and files changed to address breaking changes. Never `git add -A`.
- **GitHub-hosted deps follow different rules.** Dependencies pinned to a GitHub branch or tag cannot be upgraded via `mix hex.outdated`. Skip them and note they require manual review.
