# Migrate All Contexts to DomainEventBus

## Context

Identity and Messaging anonymization flows already dispatch through DomainEventBus.
The Messaging NotifyLiveViews handler exists and is registered. Four legacy
EventPublisher modules remain (Accounts, Participation, Community, Support) plus
six Messaging use cases still calling the old EventPublisher directly.

## Goal

Migrate every context to DomainEventBus dispatch. Delete all EventPublisher modules.
Promote Accounts cross-context events to proper integration events.

## Migration Order

1. Accounts (cross-context, other contexts depend on its events)
2. Messaging (handler exists, wire up 6 use cases + delete EventPublisher)
3. Participation (9 events, 9 use cases, UI-only)
4. Community (3 events, 2 use cases, UI-only)
5. Support (1 event, 1 use case, UI-only)
6. Final cleanup

---

## 1. Accounts

### Current flow

```
accounts.ex → EventPublisher.publish_user_registered(user, opts)
  → UserEvents.user_registered(user, payload, meta_opts)  [DomainEvent]
  → EventPublishing.publish()
  → PubSub "user:user_registered"  [tag: :domain_event]
  → EventSubscriber → IdentityEventHandler.handle_event(%{aggregate_id: ...})
```

### New flow

```
accounts.ex → DomainEventBus.dispatch(KlassHero.Accounts, domain_event)
  → PromoteIntegrationEvents handler
  → AccountsIntegrationEvents.user_registered(...)  [IntegrationEvent]
  → IntegrationEventPublishing.publish()
  → PubSub "integration:accounts:user_registered"  [tag: :integration_event]
  → EventSubscriber → IdentityEventHandler.handle_event(%{entity_id: ...})
```

### Events

| Domain event | Promoted to integration? | Error strategy | Consumers |
|---|---|---|---|
| `user_registered` | Yes | Propagate | Identity |
| `user_confirmed` | No | — | Nobody (subscribed but ignored — remove subscription) |
| `user_email_changed` | No | — | Nobody |
| `user_anonymized` | Yes | Propagate | Identity, Messaging |

### New modules

**`Accounts.Domain.Events.AccountsIntegrationEvents`**

Factory functions for the 2 promoted events:

```elixir
def user_registered(user_id, payload \\ %{}, opts \\ []) do
  IntegrationEvent.new(
    :user_registered,
    :accounts,
    :user,
    user_id,
    Map.merge(payload, %{user_id: user_id}),
    Keyword.put_new(opts, :criticality, :critical)
  )
end

def user_anonymized(user_id, payload \\ %{}, opts \\ []) do
  IntegrationEvent.new(
    :user_anonymized,
    :accounts,
    :user,
    user_id,
    Map.merge(payload, %{user_id: user_id}),
    Keyword.put_new(opts, :criticality, :critical)
  )
end
```

**`Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents`**

Handles `:user_registered` and `:user_anonymized`. Propagates errors.

```elixir
def handle(%DomainEvent{event_type: :user_registered} = event) do
  user = event.payload
  AccountsIntegrationEvents.user_registered(event.aggregate_id, user)
  |> IntegrationEventPublishing.publish()
end

def handle(%DomainEvent{event_type: :user_anonymized} = event) do
  AccountsIntegrationEvents.user_anonymized(event.aggregate_id, event.payload)
  |> IntegrationEventPublishing.publish()
end
```

### Changes to accounts.ex

Replace 4 `EventPublisher.publish_*` calls with `DomainEventBus.dispatch`:

```elixir
# Before
EventPublisher.publish_user_registered(user, registration_source: :web)

# After
DomainEventBus.dispatch(
  KlassHero.Accounts,
  UserEvents.user_registered(user, %{registration_source: :web})
)
```

Same pattern for `user_confirmed`, `user_email_changed`, `user_anonymized`.
Events without handlers dispatch and return `:ok` (no handlers = no failures).

Remove `alias Accounts.EventPublisher`.

### Changes to application.ex

Add Accounts bus:

```elixir
{KlassHero.Shared.DomainEventBus,
 context: KlassHero.Accounts,
 handlers: [
   {:user_registered,
    {KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
     :handle}, priority: 10},
   {:user_anonymized,
    {KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
     :handle}, priority: 10}
 ]}
```

Move Identity/Messaging subscribers from `event_subscribers` to
`integration_event_subscribers`:

```elixir
# Identity — drop user:user_confirmed (subscribed but ignored)
{EventSubscriber,
 handler: IdentityEventHandler,
 topics: ["integration:accounts:user_registered", "integration:accounts:user_anonymized"],
 message_tag: :integration_event,
 event_label: "Integration event"}

# Messaging
{EventSubscriber,
 handler: MessagingEventHandler,
 topics: ["integration:accounts:user_anonymized"],
 message_tag: :integration_event,
 event_label: "Integration event"}
```

Delete `event_subscribers/0` entirely (no more domain event subscribers).

### Changes to consuming EventHandlers

Both handlers pattern match on `%{aggregate_id: user_id}`. IntegrationEvent uses
`entity_id`. Update:

**IdentityEventHandler:**
```elixir
# Before
def handle_event(%{event_type: :user_registered, aggregate_id: user_id, payload: payload})
def handle_event(%{event_type: :user_anonymized, aggregate_id: user_id})

# After
def handle_event(%{event_type: :user_registered, entity_id: user_id, payload: payload})
def handle_event(%{event_type: :user_anonymized, entity_id: user_id})
```

**MessagingEventHandler:**
```elixir
# Before
def handle_event(%{event_type: :user_anonymized, aggregate_id: user_id})

# After
def handle_event(%{event_type: :user_anonymized, entity_id: user_id})
```

### Delete

`lib/klass_hero/accounts/event_publisher.ex` + tests

---

## 2. Messaging (use case migration + cleanup)

NotifyLiveViews handler already exists and is registered for 6 event types.
PromoteIntegrationEvents already handles `:user_data_anonymized`.

### 6 use cases to migrate

| Use case | Event | Factory call |
|---|---|---|
| `SendMessage` | `:message_sent` | `MessagingEvents.message_sent(conv_id, msg_id, sender_id, content, type, sent_at)` |
| `CreateDirectConversation` | `:conversation_created` | `MessagingEvents.conversation_created(conv_id, type, provider_id, participant_ids)` |
| `MarkAsRead` | `:messages_read` | `MessagingEvents.messages_read(conv_id, user_id, read_at)` |
| `BroadcastToProgram` | `:broadcast_sent` | `MessagingEvents.broadcast_sent(conv_id, program_id, provider_id, msg_id, count)` |
| `ArchiveEndedProgramConversations` | `:conversations_archived` | `MessagingEvents.conversations_archived(conv_ids, reason, count)` |
| `EnforceRetentionPolicy` | `:retention_enforced` | `MessagingEvents.retention_enforced(msgs_deleted, convs_deleted)` |

Each use case: replace `EventPublisher.publish_*(...)` with
`DomainEventBus.dispatch(@context, MessagingEvents.event_name(...))`.

NotifyLiveViews handler swallows errors → dispatch always returns `:ok` for UI
events. Use cases no longer need to pattern match on the publish result.

### Topic helpers

Make public on NotifyLiveViews:
- `conversation_topic/1`
- `user_messages_topic/1`

Add `bulk_operations_topic/0` if LiveViews subscribe to it.

### Update MessagingLiveHelper

```elixir
# Before
EventPublisher.conversation_topic(conversation_id)
EventPublisher.user_messages_topic(user_id)

# After
NotifyLiveViews.conversation_topic(conversation_id)
NotifyLiveViews.user_messages_topic(user_id)
```

### Delete

`lib/klass_hero/messaging/event_publisher.ex` + tests (if file still exists)

---

## 3. Participation

9 events across 9 use cases (including ReviseBehavioralNote). All UI-only.

### New modules

**`Participation.Adapters.Driven.Events.EventHandlers.NotifyLiveViews`**

Uses `derive_topic` pattern: `"#{aggregate_type}:#{event_type}"`.

```elixir
def handle(%DomainEvent{} = event) do
  topic = derive_topic(event)
  safe_publish(event, topic)
end

def derive_topic(%DomainEvent{aggregate_type: agg, event_type: evt}) do
  "#{agg}:#{evt}"
end

def build_topic(aggregate_type, event_type) do
  "#{aggregate_type}:#{event_type}"
end
```

All 9 event types route through the same `handle/1` — no per-event clauses needed
since derive_topic handles routing.

### Use cases to migrate

| Use case | Replace | With |
|---|---|---|
| `CreateSession` | `EventPublisher.publish(event)` | `DomainEventBus.dispatch(@context, event)` |
| `StartSession` | same | same |
| `CompleteSession` | same | same |
| `RecordCheckIn` | same | same |
| `RecordCheckOut` | same | same |
| `BulkCheckIn` | same | same |
| `SubmitBehavioralNote` | same | same |
| `ReviewBehavioralNote` | same (2 events) | same |
| `ReviseBehavioralNote` | same | same |

Each use case already builds the DomainEvent via ParticipationEvents factories,
then passes it to `EventPublisher.publish()`. Migration is mechanical: replace
`EventPublisher.publish(event)` with `DomainEventBus.dispatch(@context, event)`.

### Bus registration

```elixir
{KlassHero.Shared.DomainEventBus,
 context: KlassHero.Participation,
 handlers: [
   {:session_created, {NotifyLiveViews, :handle}},
   {:session_started, {NotifyLiveViews, :handle}},
   {:session_completed, {NotifyLiveViews, :handle}},
   {:child_checked_in, {NotifyLiveViews, :handle}},
   {:child_checked_out, {NotifyLiveViews, :handle}},
   {:child_marked_absent, {NotifyLiveViews, :handle}},
   {:behavioral_note_submitted, {NotifyLiveViews, :handle}},
   {:behavioral_note_approved, {NotifyLiveViews, :handle}},
   {:behavioral_note_rejected, {NotifyLiveViews, :handle}}
 ]}
```

### Delete

`lib/klass_hero/participation/event_publisher.ex` + tests

---

## 4. Community

3 events, 2 use cases. CommunityLive subscribes.

### New modules

**`Community.Adapters.Driven.Events.EventHandlers.NotifyLiveViews`**

Same `derive_topic` pattern as Participation. Single `handle/1` clause.

Public helpers:
- `derive_topic/1`
- `build_topic/2`

### Use cases to migrate

| Use case | Events |
|---|---|
| `AddComment` | `:comment_added` |
| `ToggleLike` | `:post_liked` or `:post_unliked` |

Replace `EventPublisher.publish_comment_added(...)` etc. with
`DomainEventBus.dispatch(@context, CommunityEvents.comment_added(...))`.

### Update CommunityLive

```elixir
# Before
PubSubEventPublisher.build_topic(:post, :post_liked)

# After
NotifyLiveViews.build_topic(:post, :post_liked)
```

### Bus registration

```elixir
{KlassHero.Shared.DomainEventBus,
 context: KlassHero.Community,
 handlers: [
   {:comment_added, {NotifyLiveViews, :handle}},
   {:post_liked, {NotifyLiveViews, :handle}},
   {:post_unliked, {NotifyLiveViews, :handle}}
 ]}
```

### Delete

`lib/klass_hero/community/event_publisher.ex` + tests

---

## 5. Support

1 event, 1 use case.

### New modules

**`Support.Adapters.Driven.Events.EventHandlers.NotifyLiveViews`**

Same `derive_topic` pattern. Single event type.

### Use case to migrate

`SubmitContactForm` — replace
`EventPublisher.publish_contact_request_submitted(request)` with
`DomainEventBus.dispatch(@context, SupportEvents.contact_request_submitted(request))`.

### Bus registration

```elixir
{KlassHero.Shared.DomainEventBus,
 context: KlassHero.Support,
 handlers: [
   {:contact_request_submitted, {NotifyLiveViews, :handle}}
 ]}
```

### Delete

`lib/klass_hero/support/event_publisher.ex` + tests

---

## 6. Final Cleanup

- Verify no remaining references to any `EventPublisher` module
- Verify no references to `PubSubEventPublisher.build_topic` from LiveViews
- `event_subscribers/0` removed from application.ex (replaced by integration subscribers)
- `mix precommit` passes clean (compile --warnings-as-errors, format, test)

---

## Commit Strategy

One commit per logical unit:

1. `feat: add AccountsIntegrationEvents and PromoteIntegrationEvents handler`
2. `refactor: migrate Accounts to dispatch through DomainEventBus`
   (includes subscriber topic changes + EventHandler updates)
3. `chore: delete Accounts.EventPublisher`
4. `refactor: migrate Messaging use cases to dispatch through DomainEventBus`
5. `chore: delete Messaging.EventPublisher, update LiveView topic refs`
6. `feat: add Participation NotifyLiveViews handler`
7. `refactor: migrate Participation use cases to dispatch through DomainEventBus`
8. `chore: delete Participation.EventPublisher`
9. `feat: add Community NotifyLiveViews handler`
10. `refactor: migrate Community use cases + CommunityLive topic refs`
11. `chore: delete Community.EventPublisher`
12. `feat: add Support NotifyLiveViews handler`
13. `refactor: migrate Support use case + delete EventPublisher`
14. `chore: remove event_subscribers/0, final cleanup`

Commits can be squashed per context if preferred.

---

## Unresolved Questions

None — all design decisions resolved during brainstorming.
