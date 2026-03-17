# Feature: Retry Helpers

> **Context:** Shared | **Status:** Active
> **Last verified:** 17f796f3

## Purpose

Provides intelligent retry logic for event-driven operations, automatically classifying errors as transient or permanent and retrying only when there is a reasonable chance of success. This shields event handlers from momentary database connection blips without masking genuine failures.

## What It Does

- Executes an operation and retries once on transient errors (`:database_connection_error`) after a configurable backoff (default 100 ms)
- Classifies errors into transient (retryable) and permanent (non-retryable) categories
- Treats `:duplicate_resource` as idempotent success, returning `:ok` instead of an error
- Logs every retry attempt and failure with unique error IDs for correlation; logs retry success without an error ID
- Unwraps step-tagged errors (e.g., `{:anonymize_messages, :database_connection_error}`) and delegates classification to the inner reason
- Offers `retry_and_normalize/2` to collapse `{:ok, result}` down to bare `:ok` for event handler contracts

## What It Does NOT Do

| Out of Scope | Handled By |
|---|---|
| Multi-retry / exponential backoff across many attempts | [NEEDS INPUT] (no implementation exists yet) |
| Circuit breaker pattern | [NEEDS INPUT] (no implementation exists yet) |
| Queue-based / persistent retry (dead-letter queue) | [NEEDS INPUT] (no implementation exists yet) |
| Deciding *what* to retry (operation construction) | Calling event handler / use case |

## Business Rules

```
GIVEN an operation that fails with :database_connection_error
WHEN  the operation is executed via retry_with_backoff/2
THEN  the system waits the configured backoff (default 100 ms) and retries exactly once
```

```
GIVEN an operation that fails with :duplicate_resource
WHEN  the operation is executed via retry_with_backoff/2
THEN  the error is treated as idempotent success and :ok is returned
```

```
GIVEN an operation that fails with a permanent error (:resource_not_found, :database_query_error, :database_unavailable, {:validation_error, _})
WHEN  the operation is executed via retry_with_backoff/2
THEN  the error is returned immediately without retry
```

```
GIVEN a transient error on the first attempt
WHEN  the retry also fails (any error)
THEN  the original error from the first attempt is returned
```

```
GIVEN a context map with a custom :backoff_ms value
WHEN  a transient error triggers a retry
THEN  the system waits the custom backoff duration instead of the 100 ms default
```

## How It Works

```mermaid
flowchart TD
    A[Caller invokes retry_with_backoff/2] --> B[Execute operation]
    B --> C{Result?}

    C -->|:ok / {:ok, result}| D[Return success]
    C -->|{:error, :duplicate_resource}| E[Log duplicate as idempotent]
    E --> F[Return :ok]

    C -->|{:error, reason}| G{Transient error?}

    G -->|Yes: :database_connection_error| H[Log retry attempt with error ID]
    H --> I[Sleep backoff_ms]
    I --> J[Execute operation again]
    J --> K{Retry result?}
    K -->|Success| L[Log retry success]
    L --> M[Return success]
    K -->|Error| N[Log retry failure with error ID]
    N --> O[Return original error]

    G -->|No: permanent error| P[Log permanent error with error ID]
    P --> Q[Return {:error, reason}]
```

## Dependencies

| Direction | Context | What |
|---|---|---|
| Provides to | Family, Provider, Messaging, and other contexts | Retry-with-backoff wrapper for event handlers and integration event handlers |
| Requires | Elixir stdlib | `Logger`, `Process.sleep/1`, `:crypto.strong_rand_bytes/1` |

## Edge Cases

- **Permanent error on first try** -- returned immediately; no retry, no backoff sleep. Logged with a unique error ID for traceability.
- **Transient error then permanent error on retry** -- the *original* first-attempt error is returned (not the retry error), preserving the initial failure context.
- **Duplicate resource** -- treated as success (`:ok`) on any attempt, including the first. Logged at debug level since it is an expected idempotent outcome.
- **Step-tagged errors** (e.g., `{:anonymize_messages, :database_connection_error}`) -- the outer step tag is unwrapped and the inner reason is classified, so retry logic works uniformly regardless of whether the use case tags its errors.
- **Custom backoff of 0 ms** -- technically valid; the retry fires immediately with no sleep beyond scheduler yield via `Process.sleep(0)`.

## Roles & Permissions

| Role | Can Do | Cannot Do |
|---|---|---|
| Infrastructure (event handlers) | Invoke `retry_with_backoff/2` and `retry_and_normalize/2` to wrap fallible operations | N/A -- this is internal infrastructure, not user-facing |

---

*Generated from code. Sections marked `[NEEDS INPUT]` require manual review.*
