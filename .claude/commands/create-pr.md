---
argument-hint: "[ready|draft]"
description: "Create a PR with reviewer-focused description (Summary, Review Focus, Test Plan)"
---

# Create Pull Request

You are creating a GitHub pull request with a reviewer-focused description. Default to `--draft` unless `$ARGUMENTS` contains `ready`.

## 1. Gather Context

Run these in parallel:

```bash
git diff main...HEAD
git log --oneline main..HEAD
git status
git rev-parse --abbrev-ref HEAD
```

If the diff is empty (no commits ahead of main), stop and inform the user.

## 2. Analyze the Diff

From the diff, identify and categorize:

- **Files added / deleted / modified** — group by type: schemas, migrations, LiveViews, components, config, tests, context modules, domain models
- **Nil-safety changes** — guards, fallback values, nil-coalescing patterns
- **Config / env changes** — new config keys, changed defaults, env-specific values
- **Deleted code / removed modules** — what was removed and why (infer from context)
- **New public APIs or modules** — new context functions, new LiveView routes
- **Dormant / commented-out sections** — code with TODO/FIXME annotations or commented blocks

## 3. Build PR Body

Construct the body using this exact structure:

### Summary (3-6 bullets)

Each bullet describes one logical change group. Be specific — name files, modules, or concepts. Use past tense ("removed X", "added Y", "wired Z to config").

### Review Focus (3-5 items, ordered by importance)

Each item follows this pattern:

```
- **Bold topic** — explanation with `file.ex:line` references
```

Good review focus topics: nil safety, config access, deleted code, new patterns, edge cases, migration safety, breaking changes.

Reference specific file and line numbers from the diff. Multiple file refs per item are fine.

### Test Plan (actionable checklist)

Items must be specific and verifiable — "verify program detail page renders when `age_range` is nil" not "check UI".

- Mark items already verified with `[x]` (e.g., `mix precommit` if you ran it)
- Mark items needing manual verification with `[ ]`
- Always include `mix precommit` as a checklist item

## 4. Derive PR Title

Build a conventional commit title from branch name + commit analysis:

- Format: `type: short description` (e.g., `fix: guard nil price in booking flow`)
- Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`, `ci`
- No emoji. No scope parens. Under 70 characters.
- Infer type from branch prefix (`feature/` → `feat`, `fix/` → `fix`, `chore/` → `chore`, etc.)

## 5. Create the PR

Determine draft mode:
- Default: `--draft`
- If `$ARGUMENTS` contains `ready`: omit `--draft`

Run:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)" --base main [--draft]
```

After creation, print the PR URL.

## 6. Post-Creation

Run `gh pr view --json url,number --jq '"PR #" + (.number|tostring) + ": " + .url'` and display the result.

## Important Rules

- No emoji anywhere in title or body
- No references to AI assistants in any output
- File:line references must point to real lines from the diff — never fabricate
- If there's an existing open PR for this branch, inform the user instead of creating a duplicate
- Always check for an existing PR first: `gh pr list --head <branch> --state open`
