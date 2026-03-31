# Design: Deliberate Adapter-Only OTel Tracing

**Issue:** [#514](https://github.com/MaxPayne89/klass-hero/issues/514) — Replace auto-instrumented OTel with deliberate, adapter-only tracing
**Date:** 2026-03-31
**Status:** Approved

## Problem

The current OpenTelemetry setup uses auto-instrumentation libraries (`opentelemetry_bandit`, `opentelemetry_phoenix`, `opentelemetry_ecto`) that trace everything — every HTTP request, route dispatch, view render, and SQL query — with no sampling. Each request generates an estimated 50-200+ spans. This has triggered 2 Honeycomb free-tier ingestion warnings and provides no engineering control over what gets traced.

## Goals

1. **Cost control** — dramatically reduce span volume to stay within Honeycomb free tier
2. **Engineering control** — deliberate, explicit tracing where we choose what to observe
3. **Architectural alignment** — trace at the adapter layer only, consistent with Ports & Adapters
4. **Central abstraction** — a shared module that wraps span creation so adapters don't need raw OTel API calls
5. **Full trace continuity** — single trace tree from HTTP request through domain events, PubSub, and Oban workers

## Approach

Adapted from the [abstracing](https://github.com/msramos/abstracing) library pattern: a `span` macro that auto-names spans from `__CALLER__` at compile time, wraps blocks in `try/rescue` for exception recording, and provides attribute helpers. Combined with context propagation infrastructure for cross-process trace continuity.

All three auto-instrumentation libraries are removed. Root spans are created by a custom Plug (HTTP) and LiveView on_mount hook. A 50% parent-based sampler acts as a safety net.

## Module Structure

```
lib/klass_hero/shared/
  tracing.ex                    # Core: span macro, attribute helpers, use macro
  tracing/
    context.ex                  # Context propagation: inject/extract helpers
    plug.ex                     # Root span: Plug for HTTP requests
    live_view_hook.ex           # Root span: on_mount hook for LiveView
    traced_worker.ex            # Oban base: use macro replacing use Oban.Worker
```

### Existing modules modified

| Module | Change |
|--------|--------|
| `PubSubEventPublisher` | Inject trace context into event metadata before broadcast |
| `PubSubIntegrationEventPublisher` | Inject trace context into integration event metadata |
| `EventSubscriber` | Extract trace context from event metadata, attach before dispatching |
| `CriticalEventSerializer` | Preserve trace context through Oban serialization |
| `application.ex` | Remove `setup_opentelemetry/0` |
| `router.ex` | Add `Tracing.Plug` to pipeline, `Tracing.LiveViewHook` to live sessions |
| `mix.exs` | Remove 3 auto-instrumentation deps |
| `config/config.exs` | Add sampler configuration |

## Design Details

### 1. Core `span` Macro — `KlassHero.Shared.Tracing`

Adapted from abstracing with targeted improvements.

**Module opt-in:**

```elixir
defmodule MyRepository do
  use KlassHero.Shared.Tracing
  # imports: span/1, span/2, set_attribute/2, set_attributes/2
end
```

**Basic span (auto-named):**

```elixir
def create(attrs) do
  span do
    # existing code unchanged
    # span auto-named "Enrollment.Repository.create/1" from __CALLER__
  end
end
```

**Span with attributes:**

```elixir
def create(attrs) do
  span do
    set_attribute("enrollment.program_id", attrs[:program_id])
    # ...
  end
end
```

**Explicit name override:**

```elixir
def fetch_content(resend_email_id) do
  span "resend_api.fetch_email_content" do
    # ...
  end
end
```

**What the macro does:**

1. Gets tracer via `:opentelemetry.get_application_tracer(__MODULE__)`
2. Calls `:otel_tracer.with_span/3` (Erlang API) to create span, execute block, end span
3. Wraps block in `try/rescue` — on exception:
   - Records exception type, message, stacktrace as span attributes
   - Sets span status to `:error`
   - Ends span explicitly (so it's collected, not lost)
   - Reraises with original stacktrace

**Span name derivation:** At compile time, `__CALLER__` provides module + function + arity. The name strips the `KlassHero.` prefix and adapter path segments for readability (e.g., `"Enrollment.Repository.create/1"`).

**Differences from abstracing:**

| Aspect | abstracing | Our adaptation |
|--------|-----------|----------------|
| Attribute values | All via `inspect/1` (lossy) | Preserve numeric types; `inspect` only for complex types |
| Span name | Strips `Elixir.` prefix only | Strips full adapter path for domain-meaningful names |
| API surface | Full (start_span, end_span, with_span, build_span_opts) | Minimal: `span`, `set_attribute`, `set_attributes` only |

### 2. Root Spans

**HTTP Requests — `Tracing.Plug`:**

- Added to the `:browser` pipeline in `router.ex`
- Creates root span named from route pattern: `"HTTP GET /programs/:id"`
- Attributes: `http.method`, `http.route`, `http.target`
- `register_before_send` callback sets `http.status_code` and error status for 5xx
- Uses route pattern (`:id` not actual UUID) for low cardinality

**LiveView — `Tracing.LiveViewHook`:**

- Added as `on_mount` hook to all five live sessions
- Fires on connected mount only (skips static render)
- Span named `"LiveView.mount DashboardLive"` (from socket's view module)
- Attributes: `liveview.module`, `liveview.action`
- Span ends when mount completes — does NOT stay open for the LiveView process lifetime
- `handle_event` adapter spans stand on their own (separate user actions)

**Nesting:** Adapter spans auto-nest under root spans via OTel's process dictionary context. No manual linking required.

### 3. Context Propagation

Two process boundaries require explicit propagation:

**`Tracing.Context` module** provides:

- `inject/0` — serializes current trace context to `%{"traceparent" => "00-..."}` map
- `attach/1` — deserializes and sets trace context in current process
- `inject_into_event/1` — merges trace context into an event's metadata map
- `attach_from_event/1` — extracts and attaches context from event metadata
- `inject_into_args/1` — merges trace context under `"trace_context"` key in job args

Uses W3C Trace Context format via `:otel_propagator_text_map`.

**Integration events (PubSub boundary):**

- Publishers inject context: `event = Tracing.Context.inject_into_event(event)` before broadcast
- `EventSubscriber` attaches context: `Tracing.Context.attach_from_event(event)` before dispatching to handler
- Both `DomainEvent` and `IntegrationEvent` have a `metadata: %{}` map — trace context is carried there alongside existing `correlation_id`/`causation_id`

**Domain events — no changes needed:** `DomainEventBus.dispatch/2` executes handlers synchronously in the caller's process. OTel process dictionary context flows naturally.

**Critical events:** `CriticalEventSerializer` preserves the `"trace_context"` key through Oban job arg serialization/deserialization, so the durable Oban fallback path also carries the trace.

### 4. TracedWorker — `Tracing.TracedWorker`

Replaces `use Oban.Worker` in traced workers:

```elixir
defmodule SendInviteEmailWorker do
  use KlassHero.Shared.Tracing.TracedWorker,
    queue: :email,
    max_attempts: 3

  @impl true
  def execute(%Oban.Job{args: %{"invite_id" => invite_id}} = job) do
    # business logic — no tracing boilerplate
  end
end
```

**What the macro provides:**

1. Passes through all Oban options to `use Oban.Worker`
2. Imports `KlassHero.Shared.Tracing` for internal `span` use
3. Defines `perform/1` that:
   - Extracts trace context from `job.args["trace_context"]`
   - Attaches context (before creating any spans)
   - Wraps `execute(job)` in a span named from the worker module
   - Sets standard attributes: `oban.queue`, `oban.worker`, `oban.attempt`, `oban.max_attempts`
   - On failure: sets `oban.will_retry` based on remaining attempts
4. Defines `@callback execute(Oban.Job.t())` for concrete workers

Other Oban callbacks (`backoff/1`, `timeout/1`) remain overridable.

Workers that don't need tracing keep `use Oban.Worker` unchanged.

### 5. Configuration & Cleanup

**Dependencies removed from `mix.exs`:**

- `opentelemetry_bandit`
- `opentelemetry_phoenix`
- `opentelemetry_ecto`

**Dependencies kept:**

- `opentelemetry` (core SDK)
- `opentelemetry_api` (API types)
- `opentelemetry_exporter` (OTLP export)

**`application.ex`:** Remove `setup_opentelemetry/0` function and its call in `start/2`.

**Sampler (`config/config.exs`):**

```elixir
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp,
  sampler: {:parent_based, %{root: {:trace_id_ratio_based, 0.5}}}
```

`parent_based` ensures entire trace trees are sampled or not (no partial traces). 50% root sampling is appropriate given the dramatically reduced span volume from deliberate tracing.

**Environment configs unchanged:**

- prod: Honeycomb OTLP endpoint + API key (runtime.exs)
- dev: stdout exporter
- test: tracing disabled (`:none`)

## Instrumentation Targets

### What gets traced

| Adapter type | Count | Rationale |
|-------------|-------|-----------|
| Persistence repositories | 15 | DB I/O — biggest latency contributor |
| ACL adapters | 7-8 | Cross-context DB queries |
| External API adapters | 2 | Network calls (Resend, S3) — highest variance |
| Oban workers | 3 | Async job execution via TracedWorker |
| Projections (selective) | 2 | Only those that do DB writes (ProgramListings, ConversationSummaries) |

### What does NOT get traced

| Type | Rationale |
|------|-----------|
| Schemas, mappers, queries | Pure data transformation, no I/O |
| Event publishers | Thin PubSub broadcast — negligible latency |
| "Promote" event handlers | One-liner delegations — just noise |
| Domain services/models | Architectural constraint — domain layer stays pure |

### Attribute conventions

```
Repositories:
  db.operation      = "insert" | "select" | "update" | "delete"
  db.entity         = "enrollment" | "program" | "message" | ...

ACL adapters:
  acl.source        = "enrollment"      (calling context)
  acl.target        = "program_catalog"  (queried context)
  acl.operation     = "resolve_program_titles"

External APIs:
  http.service      = "resend" | "s3"
  http.operation    = "fetch_email_content" | "upload"
  http.status_code  = 200 | 404 | 429 | ...

Workers (auto-set by TracedWorker):
  oban.queue        = "email" | "critical_events"
  oban.worker       = "SendInviteEmailWorker"
  oban.attempt      = 1
  oban.max_attempts = 3
  oban.will_retry   = true | false  (on failure only)
```

## Adding Tracing to New Adapters

For any new adapter written after this work:

1. `use KlassHero.Shared.Tracing`
2. Wrap public functions in `span do...end`
3. Set 1-3 relevant attributes via `set_attribute/2`
4. For Oban workers: `use KlassHero.Shared.Tracing.TracedWorker` instead of `Oban.Worker`

## Example Trace Tree

A parent enrolls a child — the full flow as a single trace:

```
HTTP POST /booking                                     [root - Plug]
  ├── Enrollment.Repository.create/1                   [adapter span]
  │     db.operation = "insert", db.entity = "enrollment"
  │
  ├── PromoteIntegrationEvents.handle/1                [domain event - same process]
  │     └── (injects trace context into event metadata)
  │
  ─── PubSub boundary ───
  │
  ├── EnrollmentEventHandler.handle_event/1            [integration event handler]
  │     └── EnqueueInviteEmails.handle/1
  │           └── (injects trace context into job args)
  │
  ─── Oban boundary ───
  │
  └── SendInviteEmailWorker.execute/1                  [TracedWorker span]
        oban.queue = "email", oban.attempt = 1
        └── ResendEmailContentAdapter.fetch_content/1  [adapter span]
              http.service = "resend", http.status_code = 200
```

## References

- [abstracing library](https://github.com/msramos/abstracing) — macro-based tracing abstraction (core pattern)
- [AppSignal: Build a Simple Tracing System in Elixir](https://blog.appsignal.com/2024/01/23/build-a-simple-tracing-system-in-elixir.html) — design rationale
- [OneUptime: Trace Oban Jobs with OTel](https://oneuptime.com/blog/post/2026-02-06-trace-oban-job-processing-opentelemetry-elixir/view) — Oban context propagation patterns
- [OneUptime: Trace GenServer/Task with OTel](https://oneuptime.com/blog/post/2026-02-06-trace-genserver-task-processes-opentelemetry-elixir/view) — process boundary patterns
