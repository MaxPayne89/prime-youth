---
description: Generate living documentation from code — features, context canvases, or cross-context flows
---

# Documentation Generator

Parse `$ARGUMENTS` to determine the mode and target. Three modes:

| Mode | Invocation | Output |
|---|---|---|
| **feature** | `/doc feature <context>/<feature-name>` | `docs/contexts/<context>/features/<feature-name>.md` |
| **context** | `/doc context <context>` | `docs/contexts/<context>/README.md` |
| **flow** | `/doc flow <flow-name>` | `docs/flows/<flow-name>.md` |

Arguments: `$ARGUMENTS`

---

## Context Name Mapping

Map the context name from the argument to the code directory:

| Argument | Code Directory | Docs Directory |
|---|---|---|
| `enrollment` | `lib/klass_hero/enrollment/` | `docs/contexts/enrollment/` |
| `family` | `lib/klass_hero/family/` | `docs/contexts/family/` |
| `provider` | `lib/klass_hero/provider/` | `docs/contexts/provider/` |
| `program-catalog` | `lib/klass_hero/program_catalog/` | `docs/contexts/program-catalog/` |
| `messaging` | `lib/klass_hero/messaging/` | `docs/contexts/messaging/` |
| `participation` | `lib/klass_hero/participation/` | `docs/contexts/participation/` |
| `accounts` | `lib/klass_hero/accounts/` | `docs/contexts/accounts/` |
| `shared` | `lib/klass_hero/shared/` | `docs/contexts/shared/` |

Note: code uses underscores (`program_catalog`), docs use hyphens (`program-catalog`).

---

## Mode: `feature`

### Step 1: Read Code Layers

Read these directories/files within the bounded context to understand the feature:

1. **Domain models** — `domain/models/` — entities, value objects, struct fields, state machines
2. **Domain ports** — `domain/ports/` — behavior contracts (these define capabilities)
3. **Domain services** — `domain/services/` — domain logic if present
4. **Domain events** — `domain/events/` — events published by this feature
5. **Use cases** — `application/use_cases/` — orchestration logic (the "what it does")
6. **Persistence schemas** — `adapters/driven/persistence/schemas/` — data shape and constraints

Focus on files relevant to the feature name. For example, `/doc feature family/child-management` should focus on child-related models, ports, use cases, and schemas.

### Step 2: Read Template

Read `docs/templates/feature.md` for the output format.

### Step 3: Generate Documentation

Fill in every template section using information extracted from code:

- **Purpose**: Derive from use case module docs and function names. Write in plain language for a PM.
- **What It Does**: List each capability found in ports and use cases.
- **What It Does NOT Do**: Identify scope boundaries from what's absent. Reference which context handles it.
- **Business Rules**: Extract from validations, guard clauses, and changeset rules. Use GIVEN/WHEN/THEN.
- **How It Works**: Create a Mermaid sequence diagram showing the flow from user action through use case, domain, and ports.
- **Dependencies**: Identify cross-context calls or events (look at adapter imports, event handlers).
- **Edge Cases**: Extract from error handling, edge-case branches, validation rules.
- **Roles & Permissions**: Derive from route scopes, authorization checks, or scope patterns.

Mark any section where the code doesn't provide enough information as `[NEEDS INPUT]`.

### Step 4: Write Output

Write to `docs/contexts/<context>/features/<feature-name>.md`.

### Step 5: Update Context README

If `docs/contexts/<context>/README.md` exists, update its "Key Features" table to include a link to the new feature doc. If the README doesn't exist yet, note this but don't create it (use `/doc context` for that).

---

## Mode: `context`

### Step 1: Read Code Layers

Read ALL files in the bounded context:

1. **All domain models** — understand the entities this context owns
2. **All ports** — understand the capabilities (inbound and outbound contracts)
3. **All events** — understand what this context publishes and subscribes to
4. **All use cases** — understand the features and workflows
5. **Persistence schemas** — understand the data this context owns
6. **Context facade** — the top-level `lib/klass_hero/<context>.ex` file (public API)
7. **Event handlers** — `adapters/driven/events/event_handlers/` — understand inbound events from other contexts

### Step 2: Read Template

Read `docs/templates/context-canvas.md` for the output format.

### Step 3: Generate Documentation

Fill in every template section:

- **Purpose**: Derive from the facade module doc and the overall shape of use cases.
- **What This Context Owns**: List all domain models, database tables, and processes.
- **Key Features**: Group use cases into user-facing features. Link to existing feature docs if they exist in `docs/contexts/<context>/features/`.
- **Inbound Communication**: Find event handlers and port implementations called by other contexts.
- **Outbound Communication**: Find events published and ports that other contexts implement.
- **Ubiquitous Language**: Extract domain terms from model names, value objects, and field names. Define each in plain language.
- **Business Decisions**: Extract key rules from validations, domain services, and use case logic.
- **Assumptions & Open Questions**: Flag anything unclear or that needs PM input.

### Step 4: Write Output

Write to `docs/contexts/<context>/README.md`.

---

## Mode: `flow`

### Step 1: Identify Contexts

The flow name should hint at which contexts are involved. Read integration events and event handlers across relevant contexts to trace the flow.

Start by reading:
1. All `domain/events/` directories across contexts for integration events
2. All `adapters/driven/events/event_handlers/` directories for cross-context subscriptions
3. Context facades for public API functions called cross-context

### Step 2: Read Template

Read `docs/templates/cross-context-flow.md` for the output format.

### Step 3: Generate Documentation

Fill in every template section:

- **Trigger**: Identify the user action or system event that starts the flow.
- **Contexts Involved**: List each context and its role.
- **Flow**: Create a Mermaid sequence diagram with max 9 messages. Show events crossing context boundaries.
- **Data Exchanged**: Document what data crosses each boundary and in what format.
- **Failure Modes**: Identify what happens when each step fails (look at error handling, compensating actions).

### Step 4: Write Output

Write to `docs/flows/<flow-name>.md`.

---

## Writing Guidelines

- **Plain language first.** Write as if the reader is a PM, not a developer.
- **Be specific.** "Creates a booking" is better than "manages enrollment data."
- **Use the code as truth.** Don't invent capabilities that aren't implemented.
- **Mark unknowns.** Use `[NEEDS INPUT]` rather than guessing business intent.
- **Keep Mermaid diagrams simple.** Max 9 messages in sequence diagrams. Show the happy path.
- **Preserve existing content.** If the doc already exists, update it rather than overwriting manually-added sections. Check for `[NEEDS INPUT]` sections that may have been filled in by a human.
