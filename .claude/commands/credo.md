---
allowed-tools: Read, Edit, Bash, Grep, Glob
argument-hint: [categories-to-ignore]
description: Run mix credo --strict and systematically fix all issues
---

# Credo - Static Analysis & Fix

Run `mix credo --strict` and systematically fix all reported issues.

**Arguments:** $ARGUMENTS (optional comma-separated categories to ignore, e.g. `TODO,TagTODO`)

## Task

### 1. Build the command

```
base: mix credo --strict
if $ARGUMENTS non-empty: append --ignore <cat> for each comma-separated category
```

### 2. Run initial analysis

Run the built credo command. Parse the output to understand scope of issues.

### 3. Fix issues file-by-file

For each file with issues (ordered by path):

1. Read the file
2. Fix all credo issues in that file top-to-bottom
3. Re-run credo scoped to that single file to verify fixes: `mix credo --strict <file>`
4. If new issues appear, fix and re-verify

### 4. Final verification

Run the full credo command again to confirm zero remaining issues.

### Rules

- Only fix what credo reports. Do not refactor or "improve" surrounding code.
- Preserve existing behavior exactly.
- For `Credo.Check.Readability.ModuleDoc` on internal/private modules, use `@moduledoc false` rather than writing filler docs.
- For `Credo.Check.Design.TagTODO` or `Credo.Check.Design.TagFIXME`, convert to beads issues (`bd create`) and remove the tag, unless the category is in the ignore list.
