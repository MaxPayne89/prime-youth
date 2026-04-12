---
name: review-architecture
description: >-
  Review code changes for DDD/Ports & Adapters architecture compliance by
  spawning the architecture-reviewer (12 structural checks) and boundary-checker
  (6 semantic violation checks) agents in parallel. Consolidates findings into
  a unified report. Use when: reviewing a PR, checking architecture before merge,
  validating structural changes, or after modifying bounded context code.
  Invoke with: /review-architecture
---

# Review Architecture

Run a comprehensive DDD/Ports & Adapters architecture review by dispatching two
specialized agents in parallel, then consolidating their reports.

**Type:** Rigid workflow. Follow steps exactly.

---

## Step 1: Determine Changed Files

Detect the review scope — what files have changed relative to the base branch.

```bash
# If on a PR branch, diff against the base
BASE=$(git merge-base HEAD main 2>/dev/null || echo "main")
git diff --name-only "$BASE"...HEAD -- '*.ex' '*.exs'
```

If there are unstaged changes (no commits yet), also include:

```bash
git diff --name-only -- '*.ex' '*.exs'
```

Filter to only Elixir files under `lib/klass_hero/` and `config/` — ignore test files,
migrations, and assets for the architecture review.

Store the file list for passing to both agents.

If no Elixir files changed, STOP:

```
No Elixir source files changed. Nothing to review.
```

## Step 2: Identify Affected Contexts

From the changed file paths, extract which bounded contexts are touched:

- `lib/klass_hero/enrollment/...` -> Enrollment
- `lib/klass_hero/family/...` -> Family
- `config/config.exs` -> Cross-cutting (DI wiring)

Display: `Affected contexts: Enrollment, Family, Shared`

This helps the user understand the review scope.

## Step 3: Spawn Both Agents in Parallel

Launch both agents **in the same message** so they run concurrently.

### Agent 1: Architecture Reviewer

Use the `architecture-reviewer` subagent. In the prompt, provide:

- The list of changed files
- The affected contexts
- Instruction to focus the 12 checks on changed files and their surrounding context

Example prompt:

```
Review these changed files for DDD/Ports & Adapters architecture compliance.
Focus your 12 checks on these files and the contexts they belong to.

Changed files:
<file list>

Affected contexts: <context list>

Run all 12 checks but scope them to the changed files and their immediate
context directories. Report findings in your standard output format.
```

### Agent 2: Boundary Checker

Use the `boundary-checker` subagent. In the prompt, provide:

- The list of changed files
- Explicit scope: `changed-files`

Example prompt:

```
Check these changed files for semantic boundary violations.

Scope: changed-files

Changed files:
<file list>

Run all 6 checks scoped to these files and their immediate references.
Report findings in your standard output format.
```

## Step 4: Consolidate Reports

Once both agents complete, merge their findings into a single unified report.

### Deduplication

Both agents may flag the same issue (e.g., a cross-context schema access would be caught
by both Check 8 of architecture-reviewer and Check 2 of boundary-checker). Deduplicate
by matching on the same file + line + violation type. Keep the more detailed description.

### Unified Report Format

```markdown
# Architecture Review Report

**Branch:** [branch name]
**Affected contexts:** [list]
**Files reviewed:** [count]

## Summary

| Source | Checks | Passed | Violations | Warnings |
|--------|--------|--------|------------|----------|
| Structure (architecture-reviewer) | 12 | N | N | N |
| Boundaries (boundary-checker) | 6 | N | N | N |
| **Total** | **18** | **N** | **N** | **N** |

## Violations

### [SEVERITY: error] CHECK_NAME — description
- **File:** path/to/file.ex:line
- **Issue:** What is wrong
- **Fix:** How to fix it

### [SEVERITY: warning] ...

## Passed Checks
- [list of all checks that passed cleanly]
```

Order violations by severity (errors first, then warnings), then by file path.

## Step 5: Present and Advise

After presenting the report:

- If **zero violations**: confirm the changes are architecturally sound
- If **only warnings**: note them but confirm the changes are acceptable
- If **errors found**: list the specific files and changes needed, and offer to fix them

---

## Rules

- **Always spawn both agents in parallel.** They are independent and run faster concurrently.
- **Always scope to changed files.** Pass the file list to both agents — do not run full-codebase scans from this skill (the user can run the agents standalone for that).
- **Deduplicate across agents.** The same violation should not appear twice in the report.
- **Never auto-fix without confirmation.** Present findings first, then offer to fix.
- **Include the full check count.** Even if all checks pass, list them so the user knows what was verified.
