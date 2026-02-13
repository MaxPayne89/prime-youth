# Development Workflow

## GitHub Issues and Branching

1. Create a GitHub issue for the work item
2. Create a branch following pattern: `[type]/[issue-number]-[short-issue-description]`
   - Types: `fix`, `feature`, `design`, etc.
   - Example: `feature/123-user-authentication`
3. Work on the branch and create a Pull Request
4. PR should reference the issue (e.g., "Closes #123") for automatic closure

## Implementation References

When implementing features, reference:

- `docs/domain-stories.md` - Business domain understanding and user journeys
- `docs/technical-architecture.md` - DDD implementation patterns and architecture
- Existing LiveView pages - Established UI patterns and component usage

## Pre-commit Checklist

Before committing, always run:

```bash
mix precommit
```

This command:

1. Compiles with `--warning-as-errors` (treats warnings as errors)
2. Runs `mix deps.unlock --unused` (removes unused deps)
3. Runs `mix format` (auto-formats code)
4. Runs `mix test` (full test suite)

**Treat all warnings as errors** - the codebase maintains zero warnings.

## Important Notes

- No references to Claude Code in commits, issues, or PRs
- Project is for a non-professional product manager - be accommodating with requirements interpretation
- Merchant codes should be set under "sumup.merchant.code" attribute
