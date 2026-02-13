# Flow: [Scenario Name]

> [1-2 sentence summary of the end-to-end flow.]

## Trigger

[What kicks off this flow — user action, scheduled event, external webhook, etc.]

## Contexts Involved

| Context | Role in Flow |
|---|---|
| [Context 1] | [What it does in this flow] |
| [Context 2] | [What it does in this flow] |
| [Context 3] | [What it does in this flow] |

## Flow

```mermaid
sequenceDiagram
    participant Context1 as [Context 1]
    participant Context2 as [Context 2]
    participant Context3 as [Context 3]

    Context1->>Context2: [message/event 1]
    Context2->>Context2: [internal step]
    Context2->>Context3: [message/event 2]
    Context3-->>Context2: [response]
    Context2-->>Context1: [final result]
```

## Data Exchanged

| Boundary Crossing | Data | Format |
|---|---|---|
| [Context 1] -> [Context 2] | [what data crosses] | [event / direct call / shared ID] |
| [Context 2] -> [Context 3] | [what data crosses] | [event / direct call / shared ID] |

## Failure Modes

| Step | Failure | What Happens |
|---|---|---|
| [Step description] | [What can go wrong] | [How the system handles it] |

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
