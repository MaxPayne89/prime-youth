# Deliberate Adapter-Only OTel Tracing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace auto-instrumented OpenTelemetry with a macro-based tracing abstraction that provides deliberate, adapter-only observability with full cross-process trace continuity.

**Architecture:** Adapted from the abstracing library — a `span` macro auto-names spans from `__CALLER__`, wraps blocks in `try/rescue` for exception recording. Context propagation via W3C Trace Context through event metadata and Oban job args. Root spans from a custom Plug (HTTP) and LiveView on_mount hook.

**Tech Stack:** Elixir 1.20, OpenTelemetry Erlang SDK 1.x (`:otel_tracer`, `:otel_span`), Phoenix 1.8, Oban 2.21

**Spec:** `docs/superpowers/specs/2026-03-31-otel-tracing-design.md`

**Key conventions:**
- **TDD everywhere** — write the failing test, see it fail, implement, see it pass
- **Tidewave MCP** — use `get_docs`, `project_eval`, `get_logs` at every verification step. If Tidewave is unavailable, alert immediately.
- **Idiomatic Elixir** — pattern matching on function heads, tagged tuples, `with` for error chains, pipe operator. Follow the idiomatic-elixir skill.

---

## File Structure

### New files

| File | Responsibility |
|------|---------------|
| `lib/klass_hero/shared/tracing.ex` | Core `span` macro, `set_attribute/2`, `set_attributes/2`, `use` macro |
| `lib/klass_hero/shared/tracing/context.ex` | Context propagation: `inject/0`, `attach/1`, event/args helpers |
| `lib/klass_hero/shared/tracing/plug.ex` | HTTP root span Plug |
| `lib/klass_hero/shared/tracing/live_view_hook.ex` | LiveView `on_mount` root span hook |
| `lib/klass_hero/shared/tracing/traced_worker.ex` | Oban base worker macro with context extraction |
| `test/klass_hero/shared/tracing_test.exs` | Tests for core span macro |
| `test/klass_hero/shared/tracing/context_test.exs` | Tests for context propagation |
| `test/klass_hero/shared/tracing/plug_test.exs` | Tests for HTTP root span |
| `test/klass_hero/shared/tracing/live_view_hook_test.exs` | Tests for LiveView hook |
| `test/klass_hero/shared/tracing/traced_worker_test.exs` | Tests for TracedWorker |
| `test/support/tracing_helpers.ex` | Shared OTel test utilities (span assertions) |

### Modified files

| File | Change |
|------|--------|
| `mix.exs` | Remove 3 auto-instrumentation deps |
| `lib/klass_hero/application.ex` | Remove `setup_opentelemetry/0` |
| `config/config.exs` | Add sampler config |
| `lib/klass_hero/shared.ex` | Add Tracing modules to boundary exports |
| `lib/klass_hero_web/router.ex` | Add Plug to pipeline, hook to live sessions |
| `lib/klass_hero/shared/adapters/driven/events/pubsub_event_publisher.ex` | Inject trace context |
| `lib/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher.ex` | Inject trace context |
| `lib/klass_hero/shared/adapters/driven/events/event_subscriber.ex` | Attach trace context |
| `lib/klass_hero/shared/adapters/driven/events/critical_event_serializer.ex` | Preserve trace context |
| 15 repository files | Add `use Tracing` + `span do...end` wrappers |
| 7-8 ACL adapter files | Add `use Tracing` + `span do...end` wrappers |
| 2 external API adapter files | Add `use Tracing` + `span do...end` wrappers |
| 3 Oban worker files | Convert from `use Oban.Worker` to `use TracedWorker` |

---

## Task 1: Remove Auto-Instrumentation & Configure Sampler

**Files:**
- Modify: `mix.exs:99-105`
- Modify: `lib/klass_hero/application.ex:22-41`
- Modify: `config/config.exs:382-385`
- Modify: `config/dev.exs:60`

- [ ] **Step 1: Remove auto-instrumentation deps from mix.exs**

In `mix.exs`, remove lines 103-105:

```elixir
# Remove these three lines:
{:opentelemetry_bandit, "~> 0.2"},
{:opentelemetry_phoenix, "~> 2.0"},
{:opentelemetry_ecto, "~> 1.1"},
```

Keep the core three:
```elixir
# OpenTelemetry
{:opentelemetry_exporter, "~> 1.6"},
{:opentelemetry, "~> 1.3"},
{:opentelemetry_api, "~> 1.2"},
```

- [ ] **Step 2: Remove setup_opentelemetry from application.ex**

In `lib/klass_hero/application.ex`, remove the call on line 23 and the function on lines 37-41:

```elixir
# Remove from start/2:
setup_opentelemetry()

# Remove entirely:
defp setup_opentelemetry do
  OpentelemetryBandit.setup()
  OpentelemetryPhoenix.setup(adapter: :bandit)
  OpentelemetryEcto.setup([:klass_hero, :repo])
end
```

- [ ] **Step 3: Add sampler to config.exs**

Replace the existing OTel config block in `config/config.exs` (lines 382-385):

```elixir
# OpenTelemetry base configuration
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp,
  sampler: {:parent_based, %{root: {:trace_id_ratio_based, 0.5}}}
```

- [ ] **Step 4: Fetch deps and compile**

Run: `mix deps.get && mix deps.unlock --unused && mix compile --warnings-as-errors`

Expected: Clean compile with no warnings. The removed deps are no longer referenced.

**Tidewave:** Use `project_eval` to verify OTel is still running:
```elixir
project_eval(code: ":opentelemetry.get_application_tracer(KlassHero)")
```
Expected: Returns a tracer reference (not an error).

- [ ] **Step 5: Run existing tests**

Run: `mix test`

Expected: All existing tests pass. The auto-instrumentors were never referenced in test code.

- [ ] **Step 6: Commit**

```bash
git add mix.exs mix.lock lib/klass_hero/application.ex config/config.exs
git commit -m "refactor: remove auto-instrumentation and configure 50% parent-based sampler

Remove opentelemetry_bandit, opentelemetry_phoenix, opentelemetry_ecto.
Keep core OTel SDK. Add parent_based sampler at 50% as safety net.
Closes the span flood — zero auto-generated spans from this point.

Refs #514"
```

---

## Task 2: Create OTel Test Helper

**Files:**
- Create: `test/support/tracing_helpers.ex`

- [ ] **Step 1: Create the test helper module**

This module provides utilities for asserting on OTel spans in tests. It uses the Erlang OTel SDK's `:otel_exporter_pid` to redirect spans to the test process.

Create `test/support/tracing_helpers.ex`:

```elixir
defmodule KlassHero.TracingHelpers do
  @moduledoc """
  Test utilities for asserting on OpenTelemetry spans.

  ## Usage

  In your test module:

      use KlassHero.TracingHelpers

  This adds a setup block that configures OTel to send spans to the
  test process. Use `assert_span/1` and `assert_span/2` to verify spans.
  """

  require Record

  @span_fields Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  Record.defrecord(:span, @span_fields)

  @status_fields Record.extract(:status, from_lib: "opentelemetry/include/otel_span.hrl")
  Record.defrecord(:status, @status_fields)

  defmacro __using__(_opts) do
    quote do
      import KlassHero.TracingHelpers

      setup do
        :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

        on_exit(fn ->
          :otel_batch_processor.set_exporter(:otel_exporter_none, %{})
        end)

        :ok
      end
    end
  end

  @doc """
  Flushes the OTel batch processor so all completed spans are exported.
  Call this after code-under-test and before assertions.
  """
  def flush_spans do
    :otel_batch_processor.force_flush()
  end

  @doc """
  Asserts a span with the given name was exported.
  Returns the full span record for further inspection.
  """
  defmacro assert_span(expected_name) do
    quote do
      KlassHero.TracingHelpers.flush_spans()

      assert_receive {:span,
                      KlassHero.TracingHelpers.span(name: name) = received_span}
                     when name == unquote(expected_name),
                     1000

      received_span
    end
  end

  @doc """
  Asserts a span with the given name was exported and verifies attributes.
  `expected_attrs` is a keyword list of `{key, value}` pairs to check.
  """
  defmacro assert_span(expected_name, expected_attrs) do
    quote do
      received_span = assert_span(unquote(expected_name))
      attrs = span_attributes(received_span)

      for {key, value} <- unquote(expected_attrs) do
        assert Map.get(attrs, key) == value,
               "Expected span attribute #{inspect(key)} to be #{inspect(value)}, " <>
                 "got #{inspect(Map.get(attrs, key))}"
      end

      received_span
    end
  end

  @doc """
  Asserts no span with the given name was exported.
  """
  defmacro refute_span(expected_name) do
    quote do
      KlassHero.TracingHelpers.flush_spans()

      refute_receive {:span,
                      KlassHero.TracingHelpers.span(name: name)}
                     when name == unquote(expected_name),
                     100
    end
  end

  @doc """
  Extracts attributes from a span record as a map of `%{key => value}`.
  """
  def span_attributes(span_record) do
    span_record
    |> span(:attributes)
    |> :otel_attributes.map()
  end

  @doc """
  Returns the status code from a span record (`:error`, `:ok`, or `:unset`).
  """
  def span_status_code(span_record) do
    span_record |> span(:status) |> status(:code)
  end
end
```

- [ ] **Step 2: Verify the helper compiles**

Run: `mix compile --warnings-as-errors`

Expected: Clean compile. The `Record.extract` calls read from the installed OTel headers.

**Tidewave:** Verify the span record fields are accessible:
```elixir
project_eval(code: "Record.extract(:span, from_lib: \"opentelemetry/include/otel_span.hrl\") |> Keyword.keys()")
```
Expected: Returns a list including `:name`, `:attributes`, `:status`, `:trace_id`, `:span_id`, etc.

- [ ] **Step 3: Commit**

```bash
git add test/support/tracing_helpers.ex
git commit -m "test: add OTel span assertion helpers for tracing tests

TracingHelpers module redirects OTel exports to test process and
provides assert_span/1-2, refute_span/1, and attribute extraction.

Refs #514"
```

---

## Task 3: TDD Core `span` Macro

**Files:**
- Create: `test/klass_hero/shared/tracing_test.exs`
- Create: `lib/klass_hero/shared/tracing.ex`

- [ ] **Step 1: Write the failing tests**

Create `test/klass_hero/shared/tracing_test.exs`:

```elixir
defmodule KlassHero.Shared.TracingTest do
  use ExUnit.Case, async: true
  use KlassHero.TracingHelpers

  # A test module that uses the Tracing macro.
  # Defined here so __CALLER__ produces a known module + function.
  defmodule TestAdapter do
    use KlassHero.Shared.Tracing

    def traced_operation do
      span do
        :result
      end
    end

    def traced_with_name do
      span "custom.span_name" do
        :named_result
      end
    end

    def traced_with_attributes do
      span do
        set_attribute("db.operation", "insert")
        set_attribute("db.entity", "enrollment")
        :attributed_result
      end
    end

    def traced_with_error do
      span do
        raise ArgumentError, "test error"
      end
    end

    def traced_with_numeric_attribute do
      span do
        set_attribute("http.status_code", 200)
        :ok
      end
    end
  end

  describe "span/1 with auto-naming" do
    test "creates a span named from module and function" do
      assert :result == TestAdapter.traced_operation()
      assert_span("Shared.TracingTest.TestAdapter.traced_operation/0")
    end

    test "returns the block's result" do
      assert :result == TestAdapter.traced_operation()
    end
  end

  describe "span/2 with explicit name" do
    test "creates a span with the given name" do
      assert :named_result == TestAdapter.traced_with_name()
      assert_span("custom.span_name")
    end
  end

  describe "set_attribute/2" do
    test "sets string attributes on the current span" do
      TestAdapter.traced_with_attributes()

      assert_span("Shared.TracingTest.TestAdapter.traced_with_attributes/0",
        "db.operation": "insert",
        "db.entity": "enrollment"
      )
    end

    test "preserves numeric attribute types" do
      TestAdapter.traced_with_numeric_attribute()

      assert_span("Shared.TracingTest.TestAdapter.traced_with_numeric_attribute/0",
        "http.status_code": 200
      )
    end
  end

  describe "exception handling" do
    test "records exception on span and reraises" do
      assert_raise ArgumentError, "test error", fn ->
        TestAdapter.traced_with_error()
      end

      span = assert_span("Shared.TracingTest.TestAdapter.traced_with_error/0")
      attrs = span_attributes(span)

      assert attrs["exception.type"] == "ArgumentError"
      assert attrs["exception.message"] == "test error"
      assert is_binary(attrs["exception.stacktrace"])
      assert span_status_code(span) == :error
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/shared/tracing_test.exs`

Expected: Compilation error — `KlassHero.Shared.Tracing` module does not exist yet.

- [ ] **Step 3: Implement the Tracing module**

Create `lib/klass_hero/shared/tracing.ex`:

```elixir
defmodule KlassHero.Shared.Tracing do
  @moduledoc """
  Central tracing abstraction for deliberate, adapter-only observability.

  Provides a `span` macro that wraps OpenTelemetry span creation with:
  - Automatic span naming from module + function + arity at compile time
  - Exception capture, recording, and reraise
  - Attribute helpers that preserve numeric types

  ## Usage

      defmodule MyRepository do
        use KlassHero.Shared.Tracing

        def create(attrs) do
          span do
            set_attribute("db.operation", "insert")
            # ... existing code
          end
        end
      end

  Adapted from the abstracing library pattern.
  """

  @noise_segments ~w[
    Elixir KlassHero Adapters Driven Driving Persistence Repositories
    Schemas Mappers Queries Events EventHandlers Workers Projections
  ]

  defmacro __using__(_opts) do
    quote do
      require OpenTelemetry.Tracer
      require KlassHero.Shared.Tracing
      import KlassHero.Shared.Tracing, only: [span: 1, span: 2, set_attribute: 2, set_attributes: 2]
    end
  end

  @doc """
  Creates a span around the given block.

  When called without a name, derives the span name from the calling
  module + function + arity at compile time.

  Wraps the block in `try/rescue` — on exception, records the error
  on the span, ends it explicitly (so it's collected), and reraises.
  """
  defmacro span(name \\ nil, do: block) do
    span_name = name || gen_span_name(__CALLER__)

    quote do
      tracer = :opentelemetry.get_application_tracer(__MODULE__)

      :otel_tracer.with_span(tracer, unquote(span_name), %{}, fn _ctx ->
        try do
          unquote(block)
        rescue
          exception ->
            ctx = OpenTelemetry.Tracer.current_span_ctx()

            :otel_span.set_attributes(ctx, [
              {:"exception.type", to_string(exception.__struct__)},
              {:"exception.message", Exception.message(exception)},
              {:"exception.stacktrace", Exception.format_stacktrace(__STACKTRACE__)}
            ])

            :otel_span.set_status(
              ctx,
              OpenTelemetry.status(:error, "exception")
            )

            :otel_span.end_span(ctx)
            reraise exception, __STACKTRACE__
        end
      end)
    end
  end

  @doc """
  Sets a single attribute on the current span.

  Preserves numeric and boolean types. Atoms are converted to strings.
  Complex types (maps, lists, structs) are converted via `inspect/1`.
  """
  def set_attribute(key, value) when is_binary(key) do
    OpenTelemetry.Tracer.set_attribute(key, normalize_value(value))
  end

  @doc """
  Sets multiple attributes on the current span from a keyword list or map.

  Each key is prefixed with the given namespace: `set_attributes("db", operation: "insert")`
  sets `"db.operation" => "insert"`.
  """
  def set_attributes(namespace, enumerable) when is_binary(namespace) do
    enumerable
    |> Enum.each(fn {key, value} ->
      set_attribute("#{namespace}.#{key}", value)
    end)
  end

  defp normalize_value(value) when is_binary(value), do: value
  defp normalize_value(value) when is_integer(value), do: value
  defp normalize_value(value) when is_float(value), do: value
  defp normalize_value(value) when is_boolean(value), do: value
  defp normalize_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_value(value), do: inspect(value)

  @doc false
  def gen_span_name(caller) do
    {function, arity} = caller.function

    module_name =
      caller.module
      |> Module.split()
      |> Enum.reject(&(&1 in @noise_segments))
      |> Enum.join(".")

    "#{module_name}.#{function}/#{arity}"
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/shared/tracing_test.exs`

Expected: All 5 tests pass.

- [ ] **Step 5: Verify zero warnings**

Run: `mix compile --warnings-as-errors`

Expected: Clean compile.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/shared/tracing.ex test/klass_hero/shared/tracing_test.exs
git commit -m "feat: add core span macro for deliberate adapter tracing

Adapted from abstracing library. Auto-names spans from __CALLER__,
wraps blocks in try/rescue for exception recording, preserves
numeric attribute types. Minimal API: span, set_attribute, set_attributes.

Refs #514"
```

---

## Task 4: TDD Context Propagation

**Files:**
- Create: `test/klass_hero/shared/tracing/context_test.exs`
- Create: `lib/klass_hero/shared/tracing/context.ex`

- [ ] **Step 1: Write the failing tests**

Create `test/klass_hero/shared/tracing/context_test.exs`:

```elixir
defmodule KlassHero.Shared.Tracing.ContextTest do
  use ExUnit.Case, async: true
  use KlassHero.TracingHelpers

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.Domain.Events.IntegrationEvent
  alias KlassHero.Shared.Tracing.Context

  describe "inject/0 and attach/1" do
    test "roundtrips trace context across processes" do
      # Create a span so there's context to propagate
      use KlassHero.Shared.Tracing

      span "parent.operation" do
        context = Context.inject()

        assert is_map(context)
        assert Map.has_key?(context, "traceparent")

        # Simulate a new process by spawning a task
        parent_span_ctx = OpenTelemetry.Tracer.current_span_ctx()

        task =
          Task.async(fn ->
            Context.attach(context)

            span "child.operation" do
              :child_result
            end
          end)

        Task.await(task)
      end

      flush_spans()

      # Both spans should share the same trace_id
      assert_receive {:span, parent_span}
      assert_receive {:span, child_span}

      parent_trace = span(parent_span, :trace_id)
      child_trace = span(child_span, :trace_id)
      assert parent_trace == child_trace
    end
  end

  describe "inject/0 when no active span" do
    test "returns empty map" do
      assert Context.inject() == %{}
    end
  end

  describe "inject_into_event/1 for DomainEvent" do
    test "merges trace context into event metadata" do
      use KlassHero.Shared.Tracing

      span "test.operation" do
        event = DomainEvent.new(:test_event, "123", :test, %{})
        enriched = Context.inject_into_event(event)

        assert Map.has_key?(enriched.metadata, "traceparent")
        # Original metadata preserved
        assert enriched.event_type == :test_event
      end
    end
  end

  describe "inject_into_event/1 for IntegrationEvent" do
    test "merges trace context into event metadata" do
      use KlassHero.Shared.Tracing

      span "test.operation" do
        event = IntegrationEvent.new(:test_event, :test, :entity, "123", %{})
        enriched = Context.inject_into_event(event)

        assert Map.has_key?(enriched.metadata, "traceparent")
      end
    end
  end

  describe "attach_from_event/1" do
    test "restores context from event metadata" do
      use KlassHero.Shared.Tracing

      span "publisher.span" do
        event = DomainEvent.new(:test_event, "123", :test, %{})
        enriched = Context.inject_into_event(event)
        context_map = enriched.metadata

        task =
          Task.async(fn ->
            Context.attach_from_event(enriched)

            span "subscriber.span" do
              :ok
            end
          end)

        Task.await(task)
      end

      flush_spans()

      assert_receive {:span, _publisher_span}
      assert_receive {:span, subscriber_span}
      # subscriber span should have a parent (not be a root span)
      assert span(subscriber_span, :parent_span_id) != :undefined
    end
  end

  describe "inject_into_args/1 and attach_from_args/1" do
    test "roundtrips trace context through job args" do
      use KlassHero.Shared.Tracing

      span "enqueue.operation" do
        args = %{"invite_id" => "abc123"}
        enriched_args = Context.inject_into_args(args)

        assert is_map(enriched_args["trace_context"])
        assert enriched_args["invite_id"] == "abc123"

        task =
          Task.async(fn ->
            Context.attach_from_args(enriched_args)

            span "worker.operation" do
              :ok
            end
          end)

        Task.await(task)
      end

      flush_spans()

      assert_receive {:span, _enqueue_span}
      assert_receive {:span, worker_span}
      assert span(worker_span, :parent_span_id) != :undefined
    end
  end

  describe "attach_from_args/1 with no trace context" do
    test "is a no-op when trace_context key is missing" do
      args = %{"invite_id" => "abc123"}
      assert :ok == Context.attach_from_args(args)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/shared/tracing/context_test.exs`

Expected: Compilation error — `KlassHero.Shared.Tracing.Context` does not exist.

- [ ] **Step 3: Implement the Context module**

Create `lib/klass_hero/shared/tracing/context.ex`:

```elixir
defmodule KlassHero.Shared.Tracing.Context do
  @moduledoc """
  Trace context propagation across process boundaries.

  Provides helpers to serialize/deserialize W3C Trace Context
  into event metadata maps and Oban job args. Uses
  `:otel_propagator_text_map` under the hood.

  ## Process boundaries requiring propagation

  1. **Integration events** — PubSub messages cross processes
  2. **Oban workers** — jobs execute in new processes

  Domain events dispatch synchronously in the caller's process
  and do NOT need explicit propagation.
  """

  @trace_context_key "trace_context"

  @doc """
  Serializes the current trace context into a map.

  Returns `%{"traceparent" => "00-..."}` if a span is active,
  or `%{}` if no active span context exists.
  """
  @spec inject() :: map()
  def inject do
    case :otel_propagator_text_map.inject([]) do
      [] -> %{}
      headers -> Map.new(headers)
    end
  end

  @doc """
  Restores trace context from a previously injected map.

  Must be called BEFORE creating any spans in the current process,
  otherwise spans become orphaned roots instead of children.
  """
  @spec attach(map()) :: :ok
  def attach(context) when is_map(context) and map_size(context) > 0 do
    headers = Enum.to_list(context)
    otel_ctx = :otel_propagator_text_map.extract(headers)
    :otel_ctx.attach(otel_ctx)
    :ok
  end

  def attach(_empty), do: :ok

  @doc """
  Injects current trace context into an event's metadata map.

  Works with both `DomainEvent` and `IntegrationEvent` structs.
  """
  @spec inject_into_event(struct()) :: struct()
  def inject_into_event(%{metadata: metadata} = event) do
    trace_context = inject()
    %{event | metadata: Map.merge(metadata, trace_context)}
  end

  @doc """
  Attaches trace context from an event's metadata map.

  Extracts the W3C traceparent header from metadata and restores
  it as the active context in the current process.
  """
  @spec attach_from_event(struct()) :: :ok
  def attach_from_event(%{metadata: metadata}) do
    attach(metadata)
  end

  def attach_from_event(_event), do: :ok

  @doc """
  Injects current trace context into Oban job args.

  Stores under the `"trace_context"` key to avoid colliding
  with business-logic keys.
  """
  @spec inject_into_args(map()) :: map()
  def inject_into_args(args) when is_map(args) do
    case inject() do
      empty when map_size(empty) == 0 -> args
      context -> Map.put(args, @trace_context_key, context)
    end
  end

  @doc """
  Attaches trace context from Oban job args.

  Reads from the `"trace_context"` key. No-op if the key is absent
  (e.g., jobs enqueued before tracing was added).
  """
  @spec attach_from_args(map()) :: :ok
  def attach_from_args(%{@trace_context_key => context}) when is_map(context) do
    attach(context)
  end

  def attach_from_args(_args), do: :ok
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/shared/tracing/context_test.exs`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/shared/tracing/context.ex test/klass_hero/shared/tracing/context_test.exs
git commit -m "feat: add trace context propagation for cross-process continuity

Tracing.Context provides inject/attach helpers for W3C Trace Context
serialization. Works with event metadata maps and Oban job args.

Refs #514"
```

---

## Task 5: TDD Tracing.Plug

**Files:**
- Create: `test/klass_hero/shared/tracing/plug_test.exs`
- Create: `lib/klass_hero/shared/tracing/plug.ex`

- [ ] **Step 1: Write the failing tests**

Create `test/klass_hero/shared/tracing/plug_test.exs`:

```elixir
defmodule KlassHero.Shared.Tracing.PlugTest do
  use ExUnit.Case, async: true
  use KlassHero.TracingHelpers
  use Plug.Test

  alias KlassHero.Shared.Tracing

  describe "call/2" do
    test "creates a root span for HTTP requests" do
      conn =
        conn(:get, "/programs/123")
        |> put_private(:phoenix_router, KlassHeroWeb.Router)
        |> Tracing.Plug.call(Tracing.Plug.init([]))
        |> Plug.Conn.send_resp(200, "ok")

      assert_span("HTTP GET /programs/123", "http.method": "GET")
    end

    test "sets http.status_code on response" do
      conn =
        conn(:post, "/booking")
        |> put_private(:phoenix_router, KlassHeroWeb.Router)
        |> Tracing.Plug.call(Tracing.Plug.init([]))
        |> Plug.Conn.send_resp(201, "created")

      assert_span("HTTP POST /booking", "http.status_code": 201)
    end

    test "sets error status for 5xx responses" do
      conn =
        conn(:get, "/error")
        |> put_private(:phoenix_router, KlassHeroWeb.Router)
        |> Tracing.Plug.call(Tracing.Plug.init([]))
        |> Plug.Conn.send_resp(500, "error")

      span_record = assert_span("HTTP GET /error")
      assert span_status_code(span_record) == :error
    end

    test "uses route pattern when available for span name" do
      conn =
        conn(:get, "/programs/some-uuid")
        |> put_private(:phoenix_router, KlassHeroWeb.Router)
        |> put_private(:plug_route, {"/programs/:id", fn -> nil end})
        |> Tracing.Plug.call(Tracing.Plug.init([]))
        |> Plug.Conn.send_resp(200, "ok")

      assert_span("HTTP GET /programs/:id")
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/shared/tracing/plug_test.exs`

Expected: Compilation error — `KlassHero.Shared.Tracing.Plug` does not exist.

- [ ] **Step 3: Implement the Plug**

Create `lib/klass_hero/shared/tracing/plug.ex`:

```elixir
defmodule KlassHero.Shared.Tracing.Plug do
  @moduledoc """
  Plug that creates a root span for each HTTP request.

  Span name uses the route pattern for low cardinality:
  `"HTTP GET /programs/:id"` rather than `"HTTP GET /programs/abc-123"`.

  ## Usage

  Add to the `:browser` pipeline in `router.ex`:

      pipeline :browser do
        plug KlassHero.Shared.Tracing.Plug
        # ...
      end
  """

  @behaviour Plug

  use KlassHero.Shared.Tracing

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    span_name = build_span_name(conn)

    tracer = :opentelemetry.get_application_tracer(__MODULE__)

    :otel_tracer.with_span(tracer, span_name, %{}, fn _ctx ->
      set_attribute("http.method", conn.method)
      set_attribute("http.target", conn.request_path)

      route = route_pattern(conn)
      if route, do: set_attribute("http.route", route)

      Plug.Conn.register_before_send(conn, fn conn ->
        set_attribute("http.status_code", conn.status)

        if conn.status >= 500 do
          ctx = OpenTelemetry.Tracer.current_span_ctx()
          :otel_span.set_status(ctx, OpenTelemetry.status(:error, "HTTP #{conn.status}"))
        end

        conn
      end)
    end)
  end

  defp build_span_name(conn) do
    route = route_pattern(conn) || conn.request_path
    "HTTP #{conn.method} #{route}"
  end

  defp route_pattern(conn) do
    case conn.private do
      %{plug_route: {route, _fun}} -> route
      _ -> nil
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/shared/tracing/plug_test.exs`

Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/shared/tracing/plug.ex test/klass_hero/shared/tracing/plug_test.exs
git commit -m "feat: add Tracing.Plug for HTTP root spans

Creates root span per request named from route pattern.
Sets method, target, route, status_code. Error status for 5xx.

Refs #514"
```

---

## Task 6: TDD LiveView Hook

**Files:**
- Create: `test/klass_hero/shared/tracing/live_view_hook_test.exs`
- Create: `lib/klass_hero/shared/tracing/live_view_hook.ex`

- [ ] **Step 1: Write the failing tests**

Create `test/klass_hero/shared/tracing/live_view_hook_test.exs`:

```elixir
defmodule KlassHero.Shared.Tracing.LiveViewHookTest do
  use ExUnit.Case, async: true
  use KlassHero.TracingHelpers

  alias KlassHero.Shared.Tracing.LiveViewHook

  defmodule FakeLive do
    # Simulates a LiveView module for span naming
  end

  describe "on_mount/4" do
    test "creates span on connected mount" do
      socket = %Phoenix.LiveView.Socket{
        connected?: true,
        view: FakeLive,
        assigns: %{__changed__: %{}, live_action: :index}
      }

      assert {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      assert_span("LiveView.mount LiveViewHookTest.FakeLive",
        "liveview.module": "LiveViewHookTest.FakeLive",
        "liveview.action": "index"
      )
    end

    test "skips span on disconnected mount" do
      socket = %Phoenix.LiveView.Socket{
        connected?: false,
        view: FakeLive,
        assigns: %{__changed__: %{}, live_action: :index}
      }

      assert {:cont, _socket} = LiveViewHook.on_mount(:trace, %{}, %{}, socket)

      refute_span("LiveView.mount LiveViewHookTest.FakeLive")
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/shared/tracing/live_view_hook_test.exs`

Expected: Compilation error — `KlassHero.Shared.Tracing.LiveViewHook` does not exist.

- [ ] **Step 3: Implement the hook**

Create `lib/klass_hero/shared/tracing/live_view_hook.ex`:

```elixir
defmodule KlassHero.Shared.Tracing.LiveViewHook do
  @moduledoc """
  LiveView `on_mount` hook that creates a root span for connected mounts.

  Skips disconnected (static render) mounts. Span ends after mount
  completes — does NOT stay open for the LiveView process lifetime.

  ## Usage

  Add to live sessions in `router.ex`:

      live_session :authenticated,
        on_mount: [
          {KlassHero.Shared.Tracing.LiveViewHook, :trace}
        ] do
        # ...
      end
  """

  use KlassHero.Shared.Tracing

  @noise_segments ~w[Elixir KlassHeroWeb KlassHero]

  def on_mount(:trace, _params, _session, %{connected?: false} = socket) do
    {:cont, socket}
  end

  def on_mount(:trace, _params, _session, %{connected?: true} = socket) do
    view_name = format_view(socket.view)
    span_name = "LiveView.mount #{view_name}"

    tracer = :opentelemetry.get_application_tracer(__MODULE__)

    :otel_tracer.with_span(tracer, span_name, %{}, fn _ctx ->
      set_attribute("liveview.module", view_name)
      set_attribute("liveview.action", to_string(socket.assigns[:live_action]))
    end)

    {:cont, socket}
  end

  defp format_view(module) do
    module
    |> Module.split()
    |> Enum.reject(&(&1 in @noise_segments))
    |> Enum.join(".")
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/shared/tracing/live_view_hook_test.exs`

Expected: All 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/shared/tracing/live_view_hook.ex test/klass_hero/shared/tracing/live_view_hook_test.exs
git commit -m "feat: add LiveView on_mount hook for root spans

Creates span on connected mount only. Named from view module.
Span ends after mount completes — not kept open for process lifetime.

Refs #514"
```

---

## Task 7: TDD TracedWorker

**Files:**
- Create: `test/klass_hero/shared/tracing/traced_worker_test.exs`
- Create: `lib/klass_hero/shared/tracing/traced_worker.ex`

- [ ] **Step 1: Write the failing tests**

Create `test/klass_hero/shared/tracing/traced_worker_test.exs`:

```elixir
defmodule KlassHero.Shared.Tracing.TracedWorkerTest do
  use ExUnit.Case, async: true
  use KlassHero.TracingHelpers

  alias KlassHero.Shared.Tracing.Context

  defmodule TestWorker do
    use KlassHero.Shared.Tracing.TracedWorker,
      queue: :test_queue,
      max_attempts: 3

    @impl true
    def execute(%Oban.Job{args: %{"value" => value}}) do
      if value == "fail", do: {:error, "intentional failure"}, else: :ok
    end
  end

  describe "perform/1" do
    test "wraps execute in a span with oban attributes" do
      job = %Oban.Job{
        args: %{"value" => "success"},
        queue: "test_queue",
        worker: "TracedWorkerTest.TestWorker",
        attempt: 1,
        max_attempts: 3
      }

      assert :ok == TestWorker.perform(job)

      assert_span("TracedWorkerTest.TestWorker.execute/1",
        "oban.queue": "test_queue",
        "oban.worker": "TracedWorkerTest.TestWorker",
        "oban.attempt": 1,
        "oban.max_attempts": 3
      )
    end

    test "propagates trace context from job args" do
      use KlassHero.Shared.Tracing

      # Simulate enqueue side: create a span and inject context
      span "enqueue.operation" do
        args = Context.inject_into_args(%{"value" => "success"})

        job = %Oban.Job{
          args: args,
          queue: "test_queue",
          worker: "TracedWorkerTest.TestWorker",
          attempt: 1,
          max_attempts: 3
        }

        # Simulate process boundary by running in a Task
        Task.async(fn -> TestWorker.perform(job) end) |> Task.await()
      end

      flush_spans()

      assert_receive {:span, enqueue_span}
      assert_receive {:span, worker_span}

      assert span(enqueue_span, :trace_id) == span(worker_span, :trace_id)
    end

    test "sets will_retry attribute on failure when attempts remain" do
      job = %Oban.Job{
        args: %{"value" => "fail"},
        queue: "test_queue",
        worker: "TracedWorkerTest.TestWorker",
        attempt: 1,
        max_attempts: 3
      }

      assert {:error, "intentional failure"} == TestWorker.perform(job)

      span_record = assert_span("TracedWorkerTest.TestWorker.execute/1")
      attrs = span_attributes(span_record)
      assert attrs["oban.will_retry"] == true
      assert span_status_code(span_record) == :error
    end

    test "sets will_retry false on final attempt failure" do
      job = %Oban.Job{
        args: %{"value" => "fail"},
        queue: "test_queue",
        worker: "TracedWorkerTest.TestWorker",
        attempt: 3,
        max_attempts: 3
      }

      assert {:error, "intentional failure"} == TestWorker.perform(job)

      span_record = assert_span("TracedWorkerTest.TestWorker.execute/1")
      attrs = span_attributes(span_record)
      assert attrs["oban.will_retry"] == false
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/shared/tracing/traced_worker_test.exs`

Expected: Compilation error — `KlassHero.Shared.Tracing.TracedWorker` does not exist.

- [ ] **Step 3: Implement TracedWorker**

Create `lib/klass_hero/shared/tracing/traced_worker.ex`:

```elixir
defmodule KlassHero.Shared.Tracing.TracedWorker do
  @moduledoc """
  Oban worker base module with built-in trace context extraction and span creation.

  Replaces `use Oban.Worker` for workers that should participate in distributed traces.

  ## Usage

      defmodule MyWorker do
        use KlassHero.Shared.Tracing.TracedWorker,
          queue: :email,
          max_attempts: 3

        @impl true
        def execute(%Oban.Job{args: %{"id" => id}}) do
          # business logic
          :ok
        end
      end

  The macro defines `perform/1` which:
  1. Extracts and attaches trace context from job args
  2. Wraps `execute/1` in a span with standard Oban attributes
  3. Records error status and retry information on failure

  Other Oban callbacks (`backoff/1`, `timeout/1`) remain overridable.
  """

  defmacro __using__(opts) do
    quote do
      use Oban.Worker, unquote(opts)
      use KlassHero.Shared.Tracing

      alias KlassHero.Shared.Tracing.Context

      @behaviour KlassHero.Shared.Tracing.TracedWorker

      @impl Oban.Worker
      def perform(%Oban.Job{} = job) do
        Context.attach_from_args(job.args)

        worker_name = KlassHero.Shared.Tracing.gen_span_name_for_worker(__MODULE__)

        tracer = :opentelemetry.get_application_tracer(__MODULE__)

        :otel_tracer.with_span(tracer, worker_name, %{}, fn _ctx ->
          set_attribute("oban.queue", to_string(job.queue))
          set_attribute("oban.worker", worker_name |> String.split(".execute") |> hd())
          set_attribute("oban.attempt", job.attempt)
          set_attribute("oban.max_attempts", job.max_attempts)

          case execute(job) do
            :ok ->
              :ok

            {:ok, result} ->
              {:ok, result}

            {:error, _reason} = error ->
              ctx = OpenTelemetry.Tracer.current_span_ctx()
              will_retry = job.attempt < job.max_attempts
              set_attribute("oban.will_retry", will_retry)
              :otel_span.set_status(ctx, OpenTelemetry.status(:error, "job failed"))
              error
          end
        end)
      end

      defoverridable perform: 1
    end
  end

  @doc """
  Callback that concrete workers must implement.
  Receives the full `%Oban.Job{}` struct.
  """
  @callback execute(Oban.Job.t()) :: :ok | {:ok, term()} | {:error, term()}
end
```

Add the helper to `lib/klass_hero/shared/tracing.ex`:

```elixir
# Add to the KlassHero.Shared.Tracing module, after gen_span_name/1:

@doc false
def gen_span_name_for_worker(module) do
  module_name =
    module
    |> Module.split()
    |> Enum.reject(&(&1 in @noise_segments))
    |> Enum.join(".")

  "#{module_name}.execute/1"
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/shared/tracing/traced_worker_test.exs`

Expected: All 4 tests pass.

- [ ] **Step 5: Run all tracing tests**

Run: `mix test test/klass_hero/shared/tracing_test.exs test/klass_hero/shared/tracing/`

Expected: All tracing tests pass (13+ tests).

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/shared/tracing.ex lib/klass_hero/shared/tracing/traced_worker.ex test/klass_hero/shared/tracing/traced_worker_test.exs
git commit -m "feat: add TracedWorker for Oban with context propagation

Replaces use Oban.Worker for traced workers. Extracts trace context
from job args, wraps execute/1 in span with standard oban.* attributes.
Records retry status on failure.

Refs #514"
```

---

## Task 8: Wire Context Propagation Into Event Infrastructure

**Files:**
- Modify: `lib/klass_hero/shared/adapters/driven/events/pubsub_event_publisher.ex`
- Modify: `lib/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher.ex`
- Modify: `lib/klass_hero/shared/adapters/driven/events/event_subscriber.ex`
- Modify: `lib/klass_hero/shared/adapters/driven/events/critical_event_serializer.ex`

- [ ] **Step 1: Inject trace context in PubSubEventPublisher**

In `lib/klass_hero/shared/adapters/driven/events/pubsub_event_publisher.ex`, add the alias and modify `publish/2`:

```elixir
# Add alias after existing aliases:
alias KlassHero.Shared.Tracing.Context

# Modify publish/2 to inject context before broadcast:
@impl true
def publish(%DomainEvent{} = event, topic) when is_binary(topic) do
  event = Context.inject_into_event(event)

  PubSubBroadcaster.broadcast(event, topic,
    config_key: :event_publisher,
    message_tag: :domain_event,
    log_label: "event",
    extra_metadata: [aggregate_id: event.aggregate_id]
  )
end
```

- [ ] **Step 2: Inject trace context in PubSubIntegrationEventPublisher**

Find and modify `lib/klass_hero/shared/adapters/driven/events/pubsub_integration_event_publisher.ex`.

Add the alias and inject context in the `publish/2` function — same pattern:

```elixir
# Add alias:
alias KlassHero.Shared.Tracing.Context

# In publish/2, add before broadcast:
event = Context.inject_into_event(event)
```

- [ ] **Step 3: Attach trace context in EventSubscriber**

In `lib/klass_hero/shared/adapters/driven/events/event_subscriber.ex`, add the alias and modify `handle_event_safely/2`:

```elixir
# Add alias after existing aliases:
alias KlassHero.Shared.Tracing.Context

# Modify handle_event_safely/2 — attach context as the FIRST thing:
defp handle_event_safely(event, %{handler: handler, event_label: label}) do
  Context.attach_from_event(event)

  if critical_integration_event?(event) do
    # ... rest unchanged
```

- [ ] **Step 4: Preserve trace context in CriticalEventSerializer**

In `lib/klass_hero/shared/adapters/driven/events/critical_event_serializer.ex`:

The serializer converts events to string-keyed maps for Oban job args. The trace context is already in `event.metadata` as `%{"traceparent" => "..."}`. The existing `serialize_metadata/1` and `deserialize_metadata/1` functions handle string keys, but we need to verify that `"traceparent"` survives the roundtrip.

**Tidewave:** Verify the current serialization handles string keys:
```elixir
project_eval(code: """
  alias KlassHero.Shared.Adapters.Driven.Events.CriticalEventSerializer
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  event = IntegrationEvent.new(:test, :test, :entity, "123", %{})
  event = %{event | metadata: Map.put(event.metadata, "traceparent", "00-abc-def-01")}

  serialized = CriticalEventSerializer.serialize(event)
  deserialized = CriticalEventSerializer.deserialize(serialized)

  deserialized.metadata
""")
```

If `"traceparent"` is preserved as-is, no changes needed. If it's dropped or mangled (e.g., `serialize_metadata/1` only handles atom keys), modify `serialize_metadata/1` to pass through string keys:

```elixir
# In serialize_metadata/1, add a clause to pass through string keys:
defp serialize_metadata(metadata) when is_map(metadata) do
  Map.new(metadata, fn
    {key, value} when is_atom(key) -> {Atom.to_string(key), serialize_metadata_value(value)}
    {key, value} when is_binary(key) -> {key, value}
  end)
end
```

- [ ] **Step 5: Run existing event tests to verify no regressions**

Run: `mix test test/klass_hero/shared/`

Expected: All shared context tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/shared/adapters/driven/events/
git commit -m "feat: wire trace context into event publishing and subscribing

Publishers inject trace context into event metadata before broadcast.
EventSubscriber attaches context before dispatching to handlers.
CriticalEventSerializer preserves trace context through Oban args.

Refs #514"
```

---

## Task 9: Boundary Exports & Router Integration

**Files:**
- Modify: `lib/klass_hero/shared.ex`
- Modify: `lib/klass_hero_web/router.ex`

- [ ] **Step 1: Add Tracing modules to Shared boundary exports**

In `lib/klass_hero/shared.ex`, add to the `exports` list:

```elixir
exports: [
  # ... existing exports ...
  Storage,
  Tracing,
  Tracing.Context,
  Tracing.Plug,
  Tracing.LiveViewHook,
  Tracing.TracedWorker
]
```

- [ ] **Step 2: Add Tracing.Plug to browser pipeline**

In `lib/klass_hero_web/router.ex`, add the plug to the `:browser` pipeline (after existing plugs but before `fetch_current_scope`):

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_flash
  plug KlassHero.Shared.Tracing.Plug
  # ... rest of pipeline
end
```

- [ ] **Step 3: Add LiveViewHook to all live sessions**

In `lib/klass_hero_web/router.ex`, add `{KlassHero.Shared.Tracing.LiveViewHook, :trace}` to the `on_mount` list of each live session. Add it as the **first** hook (before auth hooks) so the root span captures the full mount duration including auth checks:

For each `live_session` block (`:public`, `:authenticated`, `:require_provider`, `:require_parent`, `:require_staff_provider`, `:require_admin`, `:backpex_admin`, `:admin_custom`, `:require_authenticated_user`, `:current_user`), add:

```elixir
live_session :authenticated,
  on_mount: [
    {KlassHero.Shared.Tracing.LiveViewHook, :trace},
    {KlassHeroWeb.UserAuth, :require_authenticated},
    # ... rest unchanged
  ] do
```

- [ ] **Step 4: Compile and verify**

Run: `mix compile --warnings-as-errors`

Expected: Clean compile. Boundary checker passes.

- [ ] **Step 5: Run full test suite**

Run: `mix test`

Expected: All tests pass. The Plug and hook are inert in tests (tracing disabled).

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/shared.ex lib/klass_hero_web/router.ex
git commit -m "feat: integrate root spans into router pipelines and live sessions

Add Tracing.Plug to :browser pipeline for HTTP root spans.
Add LiveViewHook to all 10 live sessions for mount root spans.
Export Tracing modules from Shared boundary.

Refs #514"
```

---

## Task 10: Instrument Exemplar Adapters (One Per Type, TDD)

**Files:**
- Modify: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex`
- Modify: `lib/klass_hero/enrollment/adapters/driven/acl/program_catalog_acl.ex`
- Modify: `lib/klass_hero/messaging/adapters/driven/resend_email_content_adapter.ex`

This task instruments one example of each adapter type to establish the pattern.

- [ ] **Step 1: Instrument EnrollmentRepository (repository exemplar)**

In `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex`:

Add `use KlassHero.Shared.Tracing` after the `@behaviour` line.

Wrap each public function body in `span do...end` with appropriate attributes. Example for `create/1`:

```elixir
use KlassHero.Shared.Tracing

@impl true
def create(attrs) when is_map(attrs) do
  span do
    set_attributes("db", operation: "insert", entity: "enrollment")

    %EnrollmentSchema{}
    |> EnrollmentSchema.create_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        Logger.info("[Enrollment.Repository] Created enrollment",
          enrollment_id: schema.id,
          program_id: attrs[:program_id],
          child_id: attrs[:child_id],
          parent_id: attrs[:parent_id]
        )

        {:ok, EnrollmentMapper.to_domain(schema)}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if EctoErrorHelpers.unique_constraint_violation?(errors, :program_id) do
          Logger.warning("[Enrollment.Repository] Duplicate active enrollment",
            program_id: attrs[:program_id],
            child_id: attrs[:child_id]
          )

          {:error, :duplicate_resource}
        else
          Logger.warning("[Enrollment.Repository] Validation error creating enrollment",
            program_id: attrs[:program_id],
            child_id: attrs[:child_id],
            errors: inspect(changeset.errors)
          )

          {:error, changeset}
        end
    end
  end
end
```

Apply the same `span do...end` + `set_attributes("db", ...)` pattern to: `create_with_capacity_check/2`, `get_by_id/1`, `list_by_parent/1`, `count_monthly_bookings/3`, `list_enrolled_identity_ids/1`, `enrolled?/2`, `list_by_program/1`, `update/2`.

Use `db.operation` values: `"insert"` for creates, `"select"` for reads/lists/counts, `"update"` for updates.

- [ ] **Step 2: Instrument ProgramCatalogACL (ACL exemplar)**

In `lib/klass_hero/enrollment/adapters/driven/acl/program_catalog_acl.ex`:

```elixir
use KlassHero.Shared.Tracing

@impl true
def list_program_titles_for_provider(provider_id) when is_binary(provider_id) do
  span do
    set_attributes("acl", source: "enrollment", target: "program_catalog", operation: "list_program_titles")

    case Ecto.UUID.cast(provider_id) do
      {:ok, _} ->
        from(p in "programs",
          where: p.provider_id == type(^provider_id, :binary_id),
          select: {p.title, type(p.id, :binary_id)}
        )
        |> Repo.all()
        |> Map.new()

      :error ->
        %{}
    end
  end
end
```

- [ ] **Step 3: Instrument ResendEmailContentAdapter (external API exemplar)**

In `lib/klass_hero/messaging/adapters/driven/resend_email_content_adapter.ex`:

```elixir
use KlassHero.Shared.Tracing

@impl true
def fetch_content(resend_email_id) do
  span "resend_api.fetch_email_content" do
    set_attributes("http", service: "resend", operation: "fetch_email_content")

    extra_opts = Application.get_env(:klass_hero, :resend_req_options, [])
    req = Req.new([base_url: @base_url, auth: {:bearer, api_key()}] ++ extra_opts)

    case Req.get(req, url: "/emails/receiving/#{resend_email_id}") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        set_attribute("http.status_code", 200)
        headers = normalize_headers(body["headers"])
        {:ok, %{html: body["html"], text: body["text"], headers: headers}}

      {:ok, %Req.Response{status: status}} = response ->
        set_attribute("http.status_code", status)
        # ... rest of existing error handling unchanged
```

Note: add `set_attribute("http.status_code", status)` in each response branch.

- [ ] **Step 4: Run existing enrollment and messaging tests**

Run: `mix test test/klass_hero/enrollment/ test/klass_hero_web/live/ test/klass_hero/messaging/`

Expected: All existing tests pass. The `span` wrapper is transparent.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_repository.ex lib/klass_hero/enrollment/adapters/driven/acl/program_catalog_acl.ex lib/klass_hero/messaging/adapters/driven/resend_email_content_adapter.ex
git commit -m "feat: instrument exemplar adapters with deliberate tracing

Add span wrappers to EnrollmentRepository (repository pattern),
ProgramCatalogACL (ACL pattern), ResendEmailContentAdapter (external API pattern).
Establishes attribute conventions for each adapter type.

Refs #514"
```

---

## Task 11: Instrument All Remaining Adapters

This task applies the patterns from Task 10 to all remaining adapters. Each file gets: `use KlassHero.Shared.Tracing` + `span do...end` wrappers on public functions.

**This task can be parallelized by context** via subagent-driven development.

- [ ] **Step 1: Instrument remaining Enrollment repositories**

Files:
- `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/enrollment_policy_repository.ex` — `set_attributes("db", operation: ..., entity: "enrollment_policy")`
- `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/participant_policy_repository.ex` — `entity: "participant_policy"`
- `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex` — `entity: "bulk_enrollment_invite"`

Pattern: `use KlassHero.Shared.Tracing`, wrap each `@impl true` public function in `span do...end`.

- [ ] **Step 2: Instrument remaining Enrollment ACL adapters**

Files:
- `lib/klass_hero/enrollment/adapters/driven/acl/child_info_acl.ex` — `acl.source: "enrollment", acl.target: "family"`
- `lib/klass_hero/enrollment/adapters/driven/acl/parent_info_acl.ex` — same
- `lib/klass_hero/enrollment/adapters/driven/acl/program_schedule_acl.ex` — `acl.target: "program_catalog"`
- `lib/klass_hero/enrollment/adapters/driven/acl/participant_details_acl.ex` — `acl.target: "participation"`

- [ ] **Step 3: Instrument Family context adapters**

Repositories:
- `lib/klass_hero/family/adapters/driven/persistence/repositories/parent_profile_repository.ex` — `entity: "parent_profile"`
- `lib/klass_hero/family/adapters/driven/persistence/repositories/child_repository.ex` — `entity: "child"`
- `lib/klass_hero/family/adapters/driven/persistence/repositories/consent_repository.ex` — `entity: "consent"`

ACL adapters:
- `lib/klass_hero/family/adapters/driven/acl/child_participation_acl.ex` — `acl.source: "family", acl.target: "participation"`
- `lib/klass_hero/family/adapters/driven/acl/child_enrollment_acl.ex` — `acl.target: "enrollment"`

- [ ] **Step 4: Instrument Provider context adapters**

Repositories:
- `lib/klass_hero/provider/adapters/driven/persistence/repositories/provider_profile_repository.ex` — `entity: "provider_profile"`
- `lib/klass_hero/provider/adapters/driven/persistence/repositories/staff_member_repository.ex` — `entity: "staff_member"`
- `lib/klass_hero/provider/adapters/driven/persistence/repositories/verification_document_repository.ex` — `entity: "verification_document"`

- [ ] **Step 5: Instrument ProgramCatalog context adapters**

Repositories:
- `lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_repository.ex` — `entity: "program"`
- `lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_listings_repository.ex` — `entity: "program_listing"`

ACL adapters:
- `lib/klass_hero/program_catalog/adapters/driven/acl/enrollment_capacity_acl.ex` — `acl.source: "program_catalog", acl.target: "enrollment"`

Projections (selective — these are GenServers, wrap DB operations inside `handle_info` with `span`):
- `lib/klass_hero/program_catalog/adapters/driven/projections/program_listings.ex` — `set_attributes("db", operation: "upsert", entity: "program_listing")`

- [ ] **Step 6: Instrument Messaging context adapters**

Repositories:
- `lib/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_repository.ex` — `entity: "conversation"`
- `lib/klass_hero/messaging/adapters/driven/persistence/repositories/message_repository.ex` — `entity: "message"`
- `lib/klass_hero/messaging/adapters/driven/persistence/repositories/participant_repository.ex` — `entity: "messaging_participant"`
- `lib/klass_hero/messaging/adapters/driven/persistence/repositories/email_reply_repository.ex` — `entity: "email_reply"`
- `lib/klass_hero/messaging/adapters/driven/persistence/repositories/inbound_email_repository.ex` — `entity: "inbound_email"`
- `lib/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository.ex` — `entity: "conversation_summary"`

ACL-style resolvers:
- `lib/klass_hero/messaging/adapters/driven/enrollment/enrollment_resolver.ex` — `acl.source: "messaging", acl.target: "enrollment"`
- `lib/klass_hero/messaging/adapters/driven/accounts/user_resolver.ex` — `acl.target: "accounts"`

Projections (selective — wrap DB operations inside `handle_info` with `span`):
- `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex` — `set_attributes("db", operation: "upsert", entity: "conversation_summary")`

- [ ] **Step 7: Instrument Shared + Accounts adapters**

- `lib/klass_hero/shared/adapters/driven/storage/s3_storage_adapter.ex` — `set_attributes("http", service: "s3", operation: ...)` per function
- `lib/klass_hero/accounts/adapters/driven/persistence/repositories/user_repository.ex` — `entity: "user"`

- [ ] **Step 8: Run full test suite**

Run: `mix test`

Expected: All tests pass. Span wrappers are transparent.

- [ ] **Step 9: Commit**

```bash
git add lib/klass_hero/enrollment/ lib/klass_hero/family/ lib/klass_hero/provider/ lib/klass_hero/program_catalog/ lib/klass_hero/messaging/ lib/klass_hero/shared/adapters/driven/storage/ lib/klass_hero/accounts/
git commit -m "feat: instrument all adapter boundaries with deliberate tracing

Add span wrappers to 15 repositories, 8 ACL adapters, and S3 storage.
Consistent attribute conventions: db.operation/entity for repos,
acl.source/target/operation for ACLs, http.service/operation for APIs.

Refs #514"
```

---

## Task 12: Convert Oban Workers to TracedWorker

**Files:**
- Modify: `lib/klass_hero/enrollment/adapters/driving/workers/send_invite_email_worker.ex`
- Modify: `lib/klass_hero/family/adapters/driving/workers/process_invite_claim_worker.ex`
- Modify: `lib/klass_hero/shared/adapters/driven/workers/critical_event_worker.ex`

- [ ] **Step 1: Convert SendInviteEmailWorker**

In `lib/klass_hero/enrollment/adapters/driving/workers/send_invite_email_worker.ex`:

Replace `use Oban.Worker, queue: :email, max_attempts: 3` with:
```elixir
use KlassHero.Shared.Tracing.TracedWorker,
  queue: :email,
  max_attempts: 3
```

Rename `perform/1` to `execute/1` and change `@impl Oban.Worker` to `@impl true`:
```elixir
@impl true
def execute(%Oban.Job{args: %{"invite_id" => invite_id, "program_name" => program_name}}) do
  # ... existing body unchanged
end
```

Keep the `backoff/1` override — it remains as `@impl Oban.Worker` since TracedWorker passes through Oban.Worker:
```elixir
@impl Oban.Worker
def backoff(%Oban.Job{attempt: attempt, unsaved_error: unsaved_error}) do
  # ... unchanged
end
```

- [ ] **Step 2: Convert ProcessInviteClaimWorker**

Same pattern in `lib/klass_hero/family/adapters/driving/workers/process_invite_claim_worker.ex`:
- Replace `use Oban.Worker` with `use KlassHero.Shared.Tracing.TracedWorker`
- Rename `perform/1` to `execute/1`
- Change `@impl Oban.Worker` to `@impl true` on `execute`

- [ ] **Step 3: Convert CriticalEventWorker**

In `lib/klass_hero/shared/adapters/driven/workers/critical_event_worker.ex`:
- Replace `use Oban.Worker` with `use KlassHero.Shared.Tracing.TracedWorker`
- Rename `perform/1` to `execute/1`
- Change `@impl Oban.Worker` to `@impl true` on `execute`

Note: keep `insert_job/1` as a regular function — it's not an Oban callback.

- [ ] **Step 4: Inject trace context at enqueue sites**

Find where these workers are enqueued and add `Context.inject_into_args/1`:

In the event handler that enqueues invite emails (e.g., `EnqueueInviteEmails`):
```elixir
alias KlassHero.Shared.Tracing.Context

# Where job args are built:
args = %{"invite_id" => invite.id, "program_name" => program_name}
args = Context.inject_into_args(args)
SendInviteEmailWorker.new(args) |> Oban.insert()
```

Similarly for `CriticalEventWorker.insert_job/1` — the args map should include trace context:
```elixir
# In CriticalEventWorker.insert_job/1 or where args are built:
args = Context.inject_into_args(args)
```

- [ ] **Step 5: Run worker tests**

Run: `mix test test/klass_hero/enrollment/ test/klass_hero/family/ test/klass_hero/shared/`

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/enrollment/adapters/driving/ lib/klass_hero/family/adapters/driving/ lib/klass_hero/shared/adapters/driven/workers/ lib/klass_hero/shared/adapters/driven/events/
git commit -m "feat: convert Oban workers to TracedWorker with context propagation

Convert SendInviteEmailWorker, ProcessInviteClaimWorker, CriticalEventWorker.
Inject trace context at enqueue sites for cross-process continuity.

Refs #514"
```

---

## Task 13: Final Verification

- [ ] **Step 1: Run precommit checks**

Run: `mix precommit`

Expected: compile (zero warnings) + format + test — all green.

If warnings exist, fix them before proceeding.

- [ ] **Step 2: Verify with Tidewave — check OTel is configured**

```elixir
project_eval(code: """
  Application.get_env(:opentelemetry, :sampler) |> inspect()
""")
```

Expected: Shows `{:parent_based, %{root: {:trace_id_ratio_based, 0.5}}}`.

- [ ] **Step 3: Verify with Tidewave — trigger a traced flow**

Navigate to a page that triggers adapter calls and check logs:

```elixir
get_logs(tail: 20, grep: "span")
```

In dev mode with stdout exporter, completed spans should appear in the console output.

- [ ] **Step 4: Verify no auto-instrumentation spans**

```elixir
project_eval(code: """
  # These modules should not exist:
  [
    Code.ensure_loaded?(OpentelemetryBandit),
    Code.ensure_loaded?(OpentelemetryPhoenix),
    Code.ensure_loaded?(OpentelemetryEcto)
  ]
""")
```

Expected: `[false, false, false]` — all three auto-instrumentation modules are gone.

- [ ] **Step 5: Verify span naming**

**Tidewave:** Evaluate a repository call and check the span name format:

```elixir
project_eval(code: """
  KlassHero.Shared.Tracing.gen_span_name(%{
    module: KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentRepository,
    function: {:create, 1}
  })
""")
```

Expected: `"Enrollment.EnrollmentRepository.create/1"`

- [ ] **Step 6: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address precommit issues from tracing integration

Refs #514"
```

- [ ] **Step 7: Push to remote**

```bash
git pull --rebase
git push
git status
```

Expected: `Your branch is up to date with 'origin/feat/514-design-custom-otel-tracing-solution'.`
