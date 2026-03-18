# Issue Body Templates

Use the matching template based on issue type. Fill in all sections. Always append the Code References section.

## Feature Template (`[FEATURE]`)

```markdown
## Feature Description

{Clear description of the missing functionality and why it matters.}

## User Story

As a {parent/provider/instructor/admin}, I want {goal} so that {benefit}.

## Acceptance Criteria

- [ ] {Criterion 1}
- [ ] {Criterion 2}
- [ ] {Criterion 3}

## Code References

- {File path 1}: {what exists or is relevant}
- {File path 2}: {pattern to follow}

## Additional Context

{Architecture notes, bounded context, existing patterns to follow, or related issues.}
```

## Bug Template (`[BUG]`)

```markdown
## Describe the Bug

{Clear description of the incorrect behavior.}

## To Reproduce

1. {Step 1}
2. {Step 2}
3. {Step 3}

## Expected Behavior

{What should happen instead.}

## Environment

- Component: {backend/mobile/admin}
- Area: {which bounded context or module}

## Code References

- {File path 1}: {where the bug likely originates}
- {File path 2}: {related code}

## Additional Context

{Stack traces, logs, or related issues.}
```

## Task Template (`[TASK]`)

```markdown
## Task Description

{What needs to be done and why.}

## Definition of Done

- [ ] {Completion criterion 1}
- [ ] {Completion criterion 2}
- [ ] Tests written (if applicable)
- [ ] Documentation updated (if applicable)

## Code References

- {File path 1}: {relevant code}
- {File path 2}: {related context}

## Additional Notes

{Technical details, architectural considerations, or implementation hints.}
```
