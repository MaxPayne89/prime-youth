---
description: "Read a GitHub issue, assess validity and complexity, and scope required changes"
argument-hint: "<issue-number> [--brainstorm]"
---

# Read and Assess GitHub Issue

## Step 1: Parse Arguments

Parse `$ARGUMENTS` to extract:
- **Issue number** (required) — the first numeric argument
- **`--brainstorm` flag** (optional) — if present, invoke brainstorming skill before assessment

If no issue number is provided, ask the user for one.

## Step 2: Fetch the Issue

Run: `gh issue view <number> --json title,body,labels,state,comments,assignees`

If the issue doesn't exist or the command fails, report the error and stop.

## Step 3: Brainstorming (if requested)

If `--brainstorm` flag was present in arguments, invoke the `superpowers:brainstorming` skill before proceeding to assessment. Feed it the issue title and body as context.

## Step 4: Assess the Issue

Evaluate the issue against the codebase. Read relevant files as needed to understand the scope.

### Validity Check
- Is the issue well-defined and actionable?
- Does it relate to actual code/features in this codebase?
- Are requirements clear enough to implement?

### Complexity Rating
Rate as **low**, **medium**, or **high** based on:
- Number of bounded contexts affected
- Whether database migrations are needed
- Cross-context coordination required
- Amount of new code vs modifications
- Test coverage implications

### Scope of Changes (only if valid)
Identify:
- Which bounded contexts are affected
- Key files/modules that would change
- Whether migrations are needed
- What tests need writing/updating
- Any new dependencies or cross-context coordination

## Step 5: Output Assessment

Format the assessment as:

```
## Issue #<number>: <title>

### Validity
- **Valid:** yes/no
- **Reason:** <explanation>

### Complexity
- **Rating:** low | medium | high
- **Factors:** <what drives the complexity>

### Scope of Changes (if valid)
- **Bounded Contexts:** <which contexts are affected>
- **Files/Modules:** <key files that would change>
- **Migration needed:** yes/no
- **Test impact:** <what tests need writing/updating>
- **Dependencies:** <any new deps or cross-context coordination>
```
