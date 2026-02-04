# Domain Event Bus Redesign

## Context

The application is splitting domain events and integration events into distinct
concepts. The current implementation has use cases calling publishers directly
(EventPublisher for LiveView, IntegrationEventPublisher for cross-context).
This creates scattered publish calls and no single dispatch point.

## Decision

Redesign the DomainEventBus as a **handler registry with caller-side execution**.
One bus per bounded context. Use cases dispatch domain events to the bus; registered
handlers decide whether to react internally, promote to integration events, or
fan out to LiveView topics.

## Event Types

Three distinct event types, one dispatch point per context:

| Type | Struct | Transport | Example |
|------|--------|-----------|---------|
| Domain | `%DomainEvent{}` | Bus (synchronous, in-process) | `:message_sent`, `:user_data_anonymized` |
| Integration | `%IntegrationEvent{}` | PubSub (cross-context) | `:child_data_anonymized` |
| UI | `%DomainEvent{}` on topic | PubSub (LiveView topics) | `"conversation:{id}"` |

## Flow

```
Use case
  -> DomainEventBus.dispatch(MyContext, %DomainEvent{})
      |-- domain handler:      reacts internally (e.g. update cache)
      |-- integration handler: promotes -> IntegrationEventPublishing.publish()
      |                          -> PubSub "integration:identity:child_data_anonymized"
      |                            -> other context's EventSubscriber picks it up
      +-- UI handler:          fans out -> PubSub "conversation:{id}"
                                 -> LiveView receives update
```

## Bus Design: Registry Over Executor

The GenServer is a handler registry, not an executor. Execution happens in the
caller's process.

```elixir
def dispatch(context, %DomainEvent{} = event) do
  handlers = GenServer.call(process_name(context), {:get_handlers, event.event_type})
  execute_handlers(handlers, event)
end
```

### Why caller-side execution

- Dispatch doesn't serialize through one process -- no GenServer bottleneck
- Handler failures crash the caller, not the bus (bus stays alive)
- Process context preserved for test doubles, Ecto sandbox, telemetry
- Future sync-to-async switch changes `execute_handlers/2` only

## Handler Registration

### Init-time (primary)

Handlers declared in the supervision tree via `{Module, :function}` tuples:

```elixir
defp domain_event_buses do
  [
    {DomainEventBus,
     context: KlassHero.Identity,
     handlers: [
       {:user_anonymized, {Identity.EventHandlers.PromoteIntegrationEvents, :handle}, priority: 10}
     ]},
    {DomainEventBus,
     context: KlassHero.Messaging,
     handlers: [
       {:message_sent, {Messaging.EventHandlers.NotifyLiveViews, :handle}, priority: 20},
       {:message_data_anonymized, {Messaging.EventHandlers.PromoteIntegrationEvents, :handle}, priority: 10}
     ]}
  ]
end
```

### Runtime (secondary)

The `subscribe/4` API remains for tests and dynamic scenarios:

```elixir
DomainEventBus.subscribe(context, :event_type, handler_fn, mode: :sync)
```

### Handler opts

- `mode:` -- `:sync` (default). Reserved for future `:async` support.
- `priority:` -- integer, lower runs first. Default `100`.

### Handler location

```
context/
  adapters/
    driven/
      events/
        event_handlers/
          promote_integration_events.ex
          notify_live_views.ex
```

## Error Handling

Each handler owns its error strategy:

```elixir
# Propagates errors (Identity -- GDPR cascade requires confirmation)
def handle(%DomainEvent{} = event) do
  event |> build_integration_event() |> IntegrationEventPublishing.publish()
end

# Swallows errors (Messaging -- best-effort)
def handle(%DomainEvent{} = event) do
  case build_and_publish(event) do
    :ok -> :ok
    {:error, reason} ->
      Logger.warning("Integration event publish failed", reason: inspect(reason))
      :ok
  end
end
```

The bus collects handler results:

```elixir
defp execute_handlers(handlers, event) do
  failures =
    handlers
    |> Enum.sort_by(fn {_fn, opts} -> Keyword.get(opts, :priority, 100) end)
    |> Enum.map(fn {handler_fn, _opts} -> safe_call(handler_fn, event) end)
    |> Enum.filter(&match?({:error, _}, &1))

  if failures == [], do: :ok, else: {:error, failures}
end
```

Use cases react to `:ok` or `{:error, _}` without needing to know which handler failed.

## Migration Path

### Use cases

Stop calling publishers directly. Dispatch domain events:

```elixir
# Before
IntegrationEventPublisher.publish_message_data_anonymized(user_id)

# After
DomainEventBus.dispatch(KlassHero.Messaging,
  MessagingEvents.user_data_anonymized(user_id))
```

### Publisher modules replaced by handlers

| Current module | Becomes | Role |
|---|---|---|
| `Messaging.EventPublisher` | `Messaging.EventHandlers.NotifyLiveViews` | Fan-out to LiveView PubSub topics |
| `Messaging.IntegrationEventPublisher` | `Messaging.EventHandlers.PromoteIntegrationEvents` | Domain -> integration event |
| `Identity.IntegrationEventPublisher` | `Identity.EventHandlers.PromoteIntegrationEvents` | Domain -> integration event |

### Unchanged

- `EventPublishing` / `IntegrationEventPublishing` -- underlying transport, called by handlers
- `MessagingEvents` / `MessagingIntegrationEvents` -- event factory modules
- `EventSubscriber` -- listens on PubSub for incoming cross-context events
- PubSub topic conventions
- Test doubles (`TestEventPublisher`, `TestIntegrationEventPublisher`)

### Topic helpers

`conversation_topic/1` and `user_messages_topic/1` move from `EventPublisher`
into `NotifyLiveViews` handler (or a small shared topic helper if LiveViews
need to reference them for subscriptions).

## Future: Async Handler Support

When synchronous dispatch becomes a bottleneck:

1. Add `Task.Supervisor` to the supervision tree
2. `execute_handlers/2` partitions handlers by `mode:`
3. `:sync` handlers run sequentially, results collected
4. `:async` handlers spawned via `Task.Supervisor`, fire-and-forget
5. Only sync results returned to caller

No changes to handler registration, use case code, or handler implementations.
LiveView notification handlers are the first candidates for `:async`.

## Testing

Caller-side execution means existing test patterns work unchanged:

- **Use case tests**: dispatch goes through the bus, handlers run in the test
  process, test doubles capture events, `assert_integration_event_published/1`
  works as today.
- **Handler unit tests**: call `MyHandler.handle(%DomainEvent{})` directly with
  test doubles configured.
- **Bus tests**: verify registration, ordering, error collection.
