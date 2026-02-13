---
argument-hint: "[branch|unstaged]"
description: "Test-drive changes using Playwright and Tidewave MCP"
---

# Test-Drive Changes

You are a QA engineer test-driving code changes in a Phoenix LiveView application. Your job: find bugs, verify UI flows, and fix trivial issues.

## 1. Determine Scope

Parse `$ARGUMENTS`:
- If `unstaged` → run `git diff` (unstaged changes only)
- If `branch` or empty → run `git diff main...HEAD` (all branch changes)

Store the diff output for analysis.

## 2. Analyze the Diff

From the diff, identify:
- **Routes**: new or modified routes in `router.ex`
- **LiveViews**: new or modified LiveView modules (mount, handle_event, render)
- **Components**: new or modified HEEx templates and component functions
- **Schemas/Migrations**: new or modified Ecto schemas, changesets, migrations
- **Context functions**: new or modified context/use-case functions
- **Test files**: new or modified tests (note but don't test-drive these directly)

Create a checklist of things to verify.

## 3. Backend Verification (Tidewave MCP)

For each relevant change, use Tidewave MCP tools:

- **`project_eval`**: evaluate key code paths — call context functions with test data, verify return shapes match expectations
- **`get_ecto_schemas`**: verify schema fields match migrations and domain models
- **`execute_sql_query`**: spot-check data integrity if migrations were added
- **`get_logs`**: monitor for warnings or errors during evaluation

Focus on:
- Changeset validations actually reject bad input
- Context functions return expected `{:ok, _}` / `{:error, _}` tuples
- Associations are properly preloaded where templates access them
- No N+1 query patterns in list operations

## 4. UI Verification (Playwright MCP)

For each UI-facing change, use Playwright MCP tools:

**Setup:**
- Navigate to `http://localhost:4000`
- If routes require auth, log in first (use test credentials or register a new user)

**For each route/page:**
1. `browser_navigate` to the page
2. `browser_take_screenshot` to capture initial state
3. `browser_snapshot` to inspect DOM structure
4. Verify key elements exist (headings, forms, buttons, links)

**For forms:**
1. `browser_fill_form` with valid data → submit → verify success
2. `browser_fill_form` with invalid data → submit → verify error messages appear
3. Check `phx-change` validation feedback works in real-time

**For interactive elements:**
1. `browser_click` buttons/links → verify navigation or state changes
2. Test empty states (no data scenarios)
3. Test edge cases (very long text, special characters)

**For responsive design:**
1. `browser_resize` to mobile viewport (375x667)
2. `browser_take_screenshot` → verify layout doesn't break
3. `browser_resize` back to desktop (1280x720)

## 5. Auto-Fix Trivial Issues

If you find any of these, fix them inline immediately:
- Typos in user-facing text
- Missing CSS classes causing obvious layout breaks
- Incorrect element IDs referenced in tests
- Missing `id` attributes on forms/key elements
- Obviously wrong static text or labels

Do NOT auto-fix:
- Logic bugs requiring design decisions
- Performance issues
- Security concerns
- Anything requiring architectural changes

For each fix, note what was changed and why.

## 6. Compile Report

After all checks, produce a markdown report with this structure:

```markdown
# Test Drive Report - {date}

## Scope
- Mode: [branch|unstaged]
- Files changed: N
- Routes affected: [list]

## Backend Checks
### Passed
- [check]: [detail]

### Issues Found
- **[severity: critical|warning|info]**: [description]
  - Location: [file:line]
  - Expected: [what should happen]
  - Actual: [what happens]

## UI Checks
### Pages Tested
- [route]: [status: pass|fail|partial]
  - [screenshot reference if relevant]

### Issues Found
- **[severity]**: [description]
  - Steps to reproduce: [steps]
  - Expected: [behavior]
  - Actual: [behavior]

## Auto-Fixes Applied
- [file:line]: [what was fixed and why]

## Recommendations
- [actionable items for manual follow-up]
```

Save the report to `docs/reports/test-drive-{YYYY-MM-DD}.md` and print a summary to console.

If a report already exists for today, append a timestamp suffix: `test-drive-{YYYY-MM-DD}-{HHmm}.md`

## Important Notes

- The Phoenix server must be running (`mix phx.server` or `iex -S mix phx.server`)
- If Tidewave MCP is unavailable, alert immediately and fall back to static analysis only
- If Playwright MCP is unavailable, alert and skip UI checks
- Be thorough but efficient — focus testing effort on the most impactful changes
- Never modify test files as "auto-fixes"
