# System Note Dedup Projection Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 100-message in-memory dedup ceiling in `ReplyPrivatelyToBroadcast` with a JSONB-based system note tracker on the `conversation_summaries` projection table.

**Architecture:** Extend the existing `ConversationSummaries` GenServer projection to track system note tokens in a `system_notes` JSONB column. A GIN index enables O(1) key-existence lookups. The use case queries the projection via the existing `ForListingConversationSummaries` port instead of scanning the messages table.

**Tech Stack:** Elixir, Ecto, PostgreSQL (JSONB + GIN index), Phoenix PubSub

**Skills:** @superpowers:test-driven-development, @idiomatic-elixir, @elixir-ecto-patterns

**Spec:** `docs/superpowers/specs/2026-03-16-system-note-dedup-projection-design.md`

---

## Chunk 1: Schema, Migration, Query Module, Port, and Repository

### Task 1: Migration — Add `system_notes` JSONB column

**Files:**
- Create: `priv/repo/migrations/<timestamp>_add_system_notes_to_conversation_summaries.exs`

- [ ] **Step 1: Create the migration**

```bash
mix ecto.gen.migration add_system_notes_to_conversation_summaries
```

- [ ] **Step 2: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.AddSystemNotesToConversationSummaries do
  use Ecto.Migration

  def change do
    alter table(:conversation_summaries) do
      add :system_notes, :map, null: false, default: %{}
    end

    # Trigger: system note dedup queries use the ? (key-existence) operator
    # Why: jsonb_ops (default) supports ?, ?|, ?&, @> — jsonb_path_ops does not
    # Outcome: O(1) key lookup via GIN index regardless of table size
    create index(:conversation_summaries, [:system_notes], using: "gin")
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
mix ecto.migrate
```

Expected: migration succeeds, `system_notes` column added with GIN index.

- [ ] **Step 4: Verify via Tidewave**

Use `execute_sql_query` to confirm:
```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'conversation_summaries' AND column_name = 'system_notes';
```

Expected: `jsonb` type, default `'{}'::jsonb`.

- [ ] **Step 5: Commit**

```
feat(messaging): add system_notes JSONB column to conversation_summaries

Adds GIN-indexed JSONB column for tracking system note tokens
as part of the projection-based dedup fix (#431).
```

---

### Task 2: Update Ecto Schema

**Files:**
- Modify: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/conversation_summary_schema.ex`

- [ ] **Step 1: Add the field to the schema**

Add after the `archived_at` field (line 29):

```elixir
field :system_notes, :map, default: %{}
```

- [ ] **Step 2: Verify compilation**

```bash
mix compile --warnings-as-errors
```

Expected: compiles cleanly.

- [ ] **Step 3: Commit**

```
feat(messaging): add system_notes field to ConversationSummarySchema
```

---

### Task 3: Query Module — `ConversationSummaryQueries`

**Files:**
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/queries/conversation_summary_queries.ex`
- Create: `test/klass_hero/messaging/adapters/driven/persistence/queries/conversation_summary_queries_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Queries.ConversationSummaryQueriesTest do
  use KlassHero.DataCase, async: true

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Queries.ConversationSummaryQueries
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Repo

  describe "has_system_note_key/2" do
    test "returns true when token exists as JSONB key" do
      conversation_id = Ecto.UUID.generate()
      token = "[broadcast:#{Ecto.UUID.generate()}]"

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{token => DateTime.to_iso8601(DateTime.utc_now())}
      })

      result =
        ConversationSummaryQueries.base()
        |> ConversationSummaryQueries.by_conversation(conversation_id)
        |> ConversationSummaryQueries.has_system_note_key(token)
        |> Repo.exists?()

      assert result == true
    end

    test "returns false when token does not exist as JSONB key" do
      conversation_id = Ecto.UUID.generate()

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{}
      })

      result =
        ConversationSummaryQueries.base()
        |> ConversationSummaryQueries.by_conversation(conversation_id)
        |> ConversationSummaryQueries.has_system_note_key("[broadcast:#{Ecto.UUID.generate()}]")
        |> Repo.exists?()

      assert result == false
    end

    test "returns false when different token exists" do
      conversation_id = Ecto.UUID.generate()
      existing_token = "[broadcast:#{Ecto.UUID.generate()}]"
      missing_token = "[broadcast:#{Ecto.UUID.generate()}]"

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{existing_token => DateTime.to_iso8601(DateTime.utc_now())}
      })

      result =
        ConversationSummaryQueries.base()
        |> ConversationSummaryQueries.by_conversation(conversation_id)
        |> ConversationSummaryQueries.has_system_note_key(missing_token)
        |> Repo.exists?()

      assert result == false
    end
  end

  defp insert_summary(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      id: Ecto.UUID.generate(),
      conversation_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      conversation_type: "direct",
      participant_count: 2,
      unread_count: 0,
      system_notes: %{},
      inserted_at: now,
      updated_at: now
    }

    Repo.insert!(%ConversationSummarySchema{} |> Ecto.Changeset.change(Map.merge(defaults, attrs)))
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/messaging/adapters/driven/persistence/queries/conversation_summary_queries_test.exs
```

Expected: compilation error — `ConversationSummaryQueries` module not found.

- [ ] **Step 3: Write the query module**

Follow the composable query builder pattern from `MessageQueries`:

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Queries.ConversationSummaryQueries do
  @moduledoc """
  Composable Ecto query builders for the conversation_summaries read table.

  This module provides query functions for the read side of the CQRS pattern.
  The projection GenServer handles writes; these queries serve reads.
  """

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema

  @doc "Base query for conversation summaries."
  def base do
    from(s in ConversationSummarySchema)
  end

  @doc "Filter by conversation ID."
  def by_conversation(query, conversation_id) do
    where(query, [s], s.conversation_id == ^conversation_id)
  end

  @doc """
  Filter to rows where the given token exists as a key in the system_notes JSONB.

  Uses the PostgreSQL `?` operator which is backed by the GIN index.
  """
  def has_system_note_key(query, token) do
    where(query, [s], fragment("? \\? ?", s.system_notes, ^token))
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/messaging/adapters/driven/persistence/queries/conversation_summary_queries_test.exs
```

Expected: 3 tests, 0 failures.

- [ ] **Step 5: Commit**

```
feat(messaging): add ConversationSummaryQueries with system note lookup

Composable query builders for the conversation_summaries read table.
Includes GIN-indexed JSONB key-existence check for system note dedup.
```

---

### Task 4: Port — Add `has_system_note?/2` callback

**Files:**
- Modify: `lib/klass_hero/messaging/domain/ports/for_listing_conversation_summaries.ex`

- [ ] **Step 1: Add the callback to the port**

Add after the existing `get_total_unread_count/1` callback (after line 39):

```elixir
@doc """
Checks whether a system note with the given token exists for a conversation.

Used for idempotent system note insertion — returns true if the token
has already been projected into the conversation's system_notes JSONB.

This is a boolean existence check that bypasses the ConversationSummary
DTO entirely.
"""
@callback has_system_note?(conversation_id :: String.t(), token :: String.t()) :: boolean()
```

- [ ] **Step 2: Verify compilation warns about missing implementation**

```bash
mix compile --warnings-as-errors 2>&1 | head -20
```

Expected: warning in `ConversationSummariesRepository` about missing `has_system_note?/2`.

**Note:** Do NOT commit yet — `--warnings-as-errors` will fail due to the missing callback implementation. Proceed directly to Task 5 and commit both together.

---

### Task 5: Repository — Implement `has_system_note?/2`

**Files:**
- Modify: `lib/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository.ex`
- Create: `test/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository_has_system_note_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationSummariesRepositoryHasSystemNoteTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationSummariesRepository
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Repo

  describe "has_system_note?/2" do
    test "returns true when the token exists in system_notes" do
      conversation_id = Ecto.UUID.generate()
      token = "[broadcast:#{Ecto.UUID.generate()}]"

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{token => DateTime.to_iso8601(DateTime.utc_now())}
      })

      assert ConversationSummariesRepository.has_system_note?(conversation_id, token) == true
    end

    test "returns false when the token does not exist" do
      conversation_id = Ecto.UUID.generate()

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{}
      })

      assert ConversationSummariesRepository.has_system_note?(conversation_id, "[broadcast:#{Ecto.UUID.generate()}]") == false
    end

    test "returns false when no summary rows exist for the conversation" do
      assert ConversationSummariesRepository.has_system_note?(Ecto.UUID.generate(), "[broadcast:#{Ecto.UUID.generate()}]") == false
    end
  end

  defp insert_summary(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      id: Ecto.UUID.generate(),
      conversation_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      conversation_type: "direct",
      participant_count: 2,
      unread_count: 0,
      system_notes: %{},
      inserted_at: now,
      updated_at: now
    }

    Repo.insert!(%ConversationSummarySchema{} |> Ecto.Changeset.change(Map.merge(defaults, attrs)))
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository_has_system_note_test.exs
```

Expected: fails — either compilation warning (missing callback) or `UndefinedFunctionError`. Run without `--warnings-as-errors` if needed for the RED phase.

- [ ] **Step 3: Implement `has_system_note?/2` in the repository**

Add to `ConversationSummariesRepository` after the `get_total_unread_count/1` function:

```elixir
@impl true
def has_system_note?(conversation_id, token) do
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Queries.ConversationSummaryQueries

  ConversationSummaryQueries.base()
  |> ConversationSummaryQueries.by_conversation(conversation_id)
  |> ConversationSummaryQueries.has_system_note_key(token)
  |> Repo.exists?()
end
```

Move the alias to the module-level alias block at the top.

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository_has_system_note_test.exs
```

Expected: 3 tests, 0 failures.

- [ ] **Step 5: Verify full compilation is clean**

```bash
mix compile --warnings-as-errors
```

Expected: compiles cleanly — the missing callback warning from Task 4 is now resolved.

- [ ] **Step 6: Commit Tasks 4 + 5 together**

```
feat(messaging): add has_system_note? port callback and repository impl

Adds ForListingConversationSummaries.has_system_note?/2 for checking
system note token existence via GIN-indexed JSONB key lookup.
Closes the dedup query path from use case through port to persistence.
```

---

## Chunk 2: Projection Changes and Use Case Update

### Task 6: Projection — Track system notes on `message_sent`

**Files:**
- Modify: `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex`
- Modify: `test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs`

- [ ] **Step 1: Write the failing test — system message updates system_notes**

Add to the existing test file, inside a new `describe` block:

```elixir
describe "handle message_sent event (system notes)" do
  test "projects system note token into system_notes JSONB for system messages" do
    user_1 = user_fixture(name: "Alice Smith")
    user_2 = user_fixture(name: "Bob Jones")

    conversation_id = Ecto.UUID.generate()
    provider_id = Ecto.UUID.generate()
    broadcast_id = Ecto.UUID.generate()
    token = "[broadcast:#{broadcast_id}]"

    # Seed summary rows via conversation_created event
    created_event =
      IntegrationEvent.new(
        :conversation_created,
        :messaging,
        :conversation,
        conversation_id,
        %{
          conversation_id: conversation_id,
          type: "direct",
          provider_id: provider_id,
          participant_ids: [user_1.id, user_2.id]
        }
      )

    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      "integration:messaging:conversation_created",
      {:integration_event, created_event}
    )

    _ = :sys.get_state(@test_server_name)

    # Send a system message with broadcast token
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    sent_event =
      IntegrationEvent.new(
        :message_sent,
        :messaging,
        :conversation,
        conversation_id,
        %{
          conversation_id: conversation_id,
          message_id: Ecto.UUID.generate(),
          sender_id: user_1.id,
          content: "#{token} Re: Schedule Change",
          message_type: "system",
          sent_at: now
        }
      )

    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      "integration:messaging:message_sent",
      {:integration_event, sent_event}
    )

    _ = :sys.get_state(@test_server_name)

    # Verify system_notes JSONB was updated for both participant rows
    summaries =
      Repo.all(
        from(s in ConversationSummarySchema,
          where: s.conversation_id == ^conversation_id
        )
      )

    assert length(summaries) == 2

    for summary <- summaries do
      assert Map.has_key?(summary.system_notes, token),
             "Expected system_notes to contain key #{token}, got: #{inspect(summary.system_notes)}"
    end
  end

  test "does not update system_notes for regular text messages" do
    user_1 = user_fixture(name: "Alice Smith")
    user_2 = user_fixture(name: "Bob Jones")

    conversation_id = Ecto.UUID.generate()
    provider_id = Ecto.UUID.generate()

    created_event =
      IntegrationEvent.new(
        :conversation_created,
        :messaging,
        :conversation,
        conversation_id,
        %{
          conversation_id: conversation_id,
          type: "direct",
          provider_id: provider_id,
          participant_ids: [user_1.id, user_2.id]
        }
      )

    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      "integration:messaging:conversation_created",
      {:integration_event, created_event}
    )

    _ = :sys.get_state(@test_server_name)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    sent_event =
      IntegrationEvent.new(
        :message_sent,
        :messaging,
        :conversation,
        conversation_id,
        %{
          conversation_id: conversation_id,
          message_id: Ecto.UUID.generate(),
          sender_id: user_1.id,
          content: "Just a regular message",
          message_type: "text",
          sent_at: now
        }
      )

    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      "integration:messaging:message_sent",
      {:integration_event, sent_event}
    )

    _ = :sys.get_state(@test_server_name)

    summaries =
      Repo.all(
        from(s in ConversationSummarySchema,
          where: s.conversation_id == ^conversation_id
        )
      )

    for summary <- summaries do
      assert summary.system_notes == %{}
    end
  end

  test "system note projection is idempotent" do
    user_1 = user_fixture(name: "Alice Smith")
    user_2 = user_fixture(name: "Bob Jones")

    conversation_id = Ecto.UUID.generate()
    provider_id = Ecto.UUID.generate()
    broadcast_id = Ecto.UUID.generate()
    token = "[broadcast:#{broadcast_id}]"

    created_event =
      IntegrationEvent.new(
        :conversation_created,
        :messaging,
        :conversation,
        conversation_id,
        %{
          conversation_id: conversation_id,
          type: "direct",
          provider_id: provider_id,
          participant_ids: [user_1.id, user_2.id]
        }
      )

    Phoenix.PubSub.broadcast(
      KlassHero.PubSub,
      "integration:messaging:conversation_created",
      {:integration_event, created_event}
    )

    _ = :sys.get_state(@test_server_name)

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    content = "#{token} Re: Schedule Change"

    # Send the same system message event twice
    for _ <- 1..2 do
      sent_event =
        IntegrationEvent.new(
          :message_sent,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            message_id: Ecto.UUID.generate(),
            sender_id: user_1.id,
            content: content,
            message_type: "system",
            sent_at: now
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:message_sent",
        {:integration_event, sent_event}
      )

      _ = :sys.get_state(@test_server_name)
    end

    summary =
      Repo.one(
        from(s in ConversationSummarySchema,
          where: s.conversation_id == ^conversation_id,
          limit: 1
        )
      )

    # Token should appear exactly once as a key
    assert map_size(summary.system_notes) == 1
    assert Map.has_key?(summary.system_notes, token)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs --only describe:"handle message_sent event (system notes)"
```

Expected: tests fail — `system_notes` remains `%{}` because the projection doesn't handle it yet.

- [ ] **Step 3: Implement system note tracking in the projection**

In `conversation_summaries.ex`, modify `project_message_sent/1` to add system note tracking after the existing transaction. Add after line 452 (after the `Repo.transaction` block):

```elixir
# Trigger: message is a system note with a broadcast token
# Why: track tokens in JSONB for O(1) dedup without scanning the messages table
# Outcome: system_notes JSONB key set for this broadcast, idempotent via || merge
maybe_project_system_note(payload)
```

Add the private function at the bottom of the private functions section:

```elixir
# Trigger: a message_sent event was received
# Why: only system messages with broadcast tokens need tracking in the projection
# Outcome: if a broadcast token is found, upsert into system_notes JSONB
defp maybe_project_system_note(%{message_type: message_type, content: content} = payload)
     when message_type in [:system, "system"] do
  conversation_id = payload.conversation_id

  case Regex.run(~r/\[broadcast:[^\]]+\]/, content || "") do
    [token] ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      token_json = %{token => DateTime.to_iso8601(now)}

      from(s in ConversationSummarySchema,
        where: s.conversation_id == ^conversation_id,
        update: [
          set: [
            system_notes:
              fragment(
                "coalesce(system_notes, '{}')::jsonb || ?::jsonb",
                ^token_json
              ),
            updated_at: ^now
          ]
        ]
      )
      |> Repo.update_all([])

    _ ->
      :ok
  end
end

defp maybe_project_system_note(_payload), do: :ok
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs
```

Expected: all tests pass, including the 3 new system note tests.

- [ ] **Step 5: Commit**

```
feat(messaging): project system note tokens into JSONB on message_sent

The ConversationSummaries projection now extracts broadcast tokens
from system messages and upserts them into the system_notes JSONB
column. Idempotent via jsonb_concat merge.
```

---

### Task 7: Projection — Bootstrap system notes from write tables

**Files:**
- Modify: `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex`
- Modify: `test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs`

- [ ] **Step 1: Write the failing test**

Add to the `describe "bootstrap"` block in the test file:

```elixir
test "bootstraps system_notes from existing system messages" do
  user_1 = user_fixture(name: "Alice Smith")
  user_2 = user_fixture(name: "Bob Jones")
  provider = insert(:provider_profile_schema)

  conversation_id = Ecto.UUID.generate()
  broadcast_id = Ecto.UUID.generate()
  token = "[broadcast:#{broadcast_id}]"

  Repo.insert!(%ConversationSchema{
    id: conversation_id,
    type: "direct",
    provider_id: provider.id
  })

  now = DateTime.utc_now() |> DateTime.truncate(:second)

  Repo.insert!(%ParticipantSchema{
    id: Ecto.UUID.generate(),
    conversation_id: conversation_id,
    user_id: user_1.id,
    joined_at: now
  })

  Repo.insert!(%ParticipantSchema{
    id: Ecto.UUID.generate(),
    conversation_id: conversation_id,
    user_id: user_2.id,
    joined_at: now
  })

  # Insert a system message with broadcast token
  Repo.insert!(%MessageSchema{
    id: Ecto.UUID.generate(),
    conversation_id: conversation_id,
    sender_id: user_1.id,
    content: "#{token} Re: Schedule Change",
    message_type: "system",
    inserted_at: now,
    updated_at: now
  })

  # Also insert a regular message (should not appear in system_notes)
  Repo.insert!(%MessageSchema{
    id: Ecto.UUID.generate(),
    conversation_id: conversation_id,
    sender_id: user_2.id,
    content: "Latest message",
    message_type: "text",
    inserted_at: now,
    updated_at: now
  })

  # Stop the default test server and start fresh for bootstrap
  stop_supervised!(ConversationSummaries)

  bootstrap_name = :"bootstrap_sysnotes_#{System.unique_integer([:positive])}"

  bootstrap_pid =
    start_supervised!({ConversationSummaries, name: bootstrap_name}, id: :bootstrap_sysnotes)

  _ = :sys.get_state(bootstrap_pid)

  summary =
    Repo.one(
      from(s in ConversationSummarySchema,
        where: s.conversation_id == ^conversation_id and s.user_id == ^user_1.id
      )
    )

  assert summary != nil
  assert Map.has_key?(summary.system_notes, token)
  assert summary.latest_message_content == "Latest message"
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs --only describe:"bootstrap"
```

Expected: the new test fails — `system_notes` is `%{}` after bootstrap.

- [ ] **Step 3: Implement bootstrap for system notes**

Add a new helper function `fetch_system_notes/1` in the projection:

```elixir
# Trigger: bootstrap needs system note tokens for conversations
# Why: without this, the system_notes JSONB would be empty until the next
#      message_sent event — breaking dedup for conversations bootstrapped from
#      the write tables
# Outcome: map of conversation_id => %{token => iso8601_timestamp}
defp fetch_system_notes(conversation_ids) when conversation_ids != [] do
  from(m in MessageSchema,
    where:
      m.conversation_id in ^conversation_ids and
        m.message_type == "system" and
        is_nil(m.deleted_at) and
        like(m.content, "[broadcast:%"),
    select: %{
      conversation_id: m.conversation_id,
      content: m.content,
      inserted_at: m.inserted_at
    }
  )
  |> Repo.all()
  |> Enum.group_by(& &1.conversation_id)
  |> Map.new(fn {conv_id, messages} ->
    notes =
      messages
      |> Enum.flat_map(fn msg ->
        case Regex.run(~r/\[broadcast:[^\]]+\]/, msg.content || "") do
          [token] -> [{token, DateTime.to_iso8601(msg.inserted_at)}]
          _ -> []
        end
      end)
      |> Map.new()

    {conv_id, notes}
  end)
end

defp fetch_system_notes(_), do: %{}
```

Update `bootstrap_from_write_tables/0` to call `fetch_system_notes/1` and pass the result into `build_conversation_entries`:

In `bootstrap_from_write_tables/0`, after `latest_messages = fetch_latest_messages(conversation_ids)` (line 268), add:

```elixir
system_notes = fetch_system_notes(conversation_ids)
```

Update the `build_conversation_entries` call to pass `system_notes`:

```elixir
build_conversation_entries(
  conversation,
  user_names,
  latest_messages,
  unread_counts,
  system_notes,
  now
)
```

Update `build_conversation_entries/6` (was `/5`) to accept and forward:

```elixir
defp build_conversation_entries(conversation, user_names, latest_messages, unread_counts, system_notes, now) do
  active_participants = Enum.filter(conversation.participants, &is_nil(&1.left_at))
  participant_count = length(active_participants)
  latest_message = Map.get(latest_messages, conversation.id)
  conv_system_notes = Map.get(system_notes, conversation.id, %{})

  Enum.map(active_participants, fn participant ->
    build_summary_entry(
      conversation,
      participant,
      active_participants,
      user_names,
      latest_message,
      unread_counts,
      participant_count,
      conv_system_notes,
      now
    )
  end)
end
```

Update `build_summary_entry/9` (was `/8`) to include `system_notes` in the entry map:

Add `system_notes` parameter and include it in the returned map:

```elixir
system_notes: conv_system_notes,
```

Add it in the map returned by `build_summary_entry`, after the `archived_at` line.

- [ ] **Step 4: Run tests to verify they pass**

```bash
mix test test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs
```

Expected: all tests pass, including the new bootstrap test.

- [ ] **Step 5: Commit**

```
feat(messaging): bootstrap system_notes from existing system messages

During projection bootstrap, fetches system messages with broadcast
tokens from the write table and populates the system_notes JSONB.
```

---

### Task 8: Use Case — Switch to projection-based dedup

**Files:**
- Modify: `lib/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast.ex`
- Modify: `test/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast_test.exs`

- [ ] **Step 1: Write the regression test (>100 messages)**

Add to the existing test file:

```elixir
test "dedup works with more than 100 messages in the conversation (regression #431)", ctx do
  # First call creates the direct conversation and system note
  {:ok, conversation_id} =
    ReplyPrivatelyToBroadcast.execute(ctx.scope, ctx.broadcast.id)

  # Insert 110 regular messages to push the system note beyond the old 100-message ceiling
  for i <- 1..110 do
    insert(:message_schema,
      conversation_id: conversation_id,
      sender_id: ctx.parent_user.id,
      content: "Message #{i}",
      message_type: "text"
    )
  end

  # Second call should still detect the existing system note (no duplicate)
  {:ok, ^conversation_id} =
    ReplyPrivatelyToBroadcast.execute(ctx.scope, ctx.broadcast.id)

  {:ok, messages, _} =
    MessageRepository.list_for_conversation(conversation_id, limit: 200)

  system_messages = Enum.filter(messages, &(&1.message_type == :system))
  assert length(system_messages) == 1
end
```

- [ ] **Step 2: Run test to verify it fails with the current implementation**

```bash
mix test test/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast_test.exs
```

Expected: the new regression test fails — the current 100-message ceiling causes a duplicate system note.

Note: this may actually pass if the projection is now handling the event (since `send_message` publishes `message_sent`, which the projection picks up). If it passes, that's fine — it means the projection is already working. Proceed to Step 3 to clean up the use case anyway.

- [ ] **Step 3: Update the use case to use the projection**

In `reply_privately_to_broadcast.ex`:

**3a.** Replace the private `system_note_exists?/3` function (lines 154-161) to query the projection:

Replace:

```elixir
defp system_note_exists?(conversation_id, token, message_repo) do
  {:ok, messages, _} =
    message_repo.list_for_conversation(conversation_id, limit: 100)

  Enum.any?(messages, fn msg ->
    msg.message_type == :system and String.contains?(msg.content, token)
  end)
end
```

With:

```elixir
defp system_note_exists?(conversation_id, token, repos) do
  repos.conversation_summaries.has_system_note?(conversation_id, token)
end
```

Update the call site in `maybe_insert_system_note/4` (line 139) to pass `repos` instead of `repos.messages`:

```elixir
if system_note_exists?(direct_conversation.id, token, repos) do
```

**3b.** Fix the race condition: the projection processes `message_sent` events
asynchronously. If `execute/2` is called twice in rapid succession, the second
call's `has_system_note?` may run before the projection has processed the first
call's event. Add a synchronous write-through after `send_message` succeeds.

In `maybe_insert_system_note/4`, after the `send_message` call succeeds, write
the token directly to the projection table:

Replace the existing `maybe_insert_system_note/4` body:

```elixir
defp maybe_insert_system_note(direct_conversation, sender_id, broadcast, repos) do
  token = "[broadcast:#{broadcast.id}]"

  if system_note_exists?(direct_conversation.id, token, repos) do
    :ok
  else
    subject = broadcast.subject || "broadcast"
    content = "#{token} Re: #{subject}"

    with {:ok, _message} <-
           Messaging.send_message(direct_conversation.id, sender_id, content,
             message_type: :system
           ) do
      # Trigger: system note just written to messages table
      # Why: the projection processes message_sent events asynchronously —
      #      without this write-through, a rapid second call could miss the
      #      token and insert a duplicate
      # Outcome: token immediately visible in the projection table; the
      #          projection's async handler is idempotent and harmless
      repos.conversation_summaries.write_system_note_token(
        direct_conversation.id,
        token
      )

      :ok
    end
  end
end
```

**3c.** Add `write_system_note_token/2` to the port and repository.

In `for_listing_conversation_summaries.ex`, add:

```elixir
@doc """
Writes a system note token directly to the conversation_summaries JSONB.

This is a synchronous write-through used by use cases that need immediate
visibility of the token. The projection also writes it asynchronously via
the message_sent event — both writes are idempotent via JSONB merge.
"""
@callback write_system_note_token(conversation_id :: String.t(), token :: String.t()) :: :ok
```

In `conversation_summaries_repository.ex`, add:

```elixir
@impl true
def write_system_note_token(conversation_id, token) do
  now = DateTime.utc_now() |> DateTime.truncate(:second)
  token_json = %{token => DateTime.to_iso8601(now)}

  from(s in ConversationSummarySchema,
    where: s.conversation_id == ^conversation_id,
    update: [
      set: [
        system_notes:
          fragment(
            "coalesce(system_notes, '{}')::jsonb || ?::jsonb",
            ^token_json
          ),
        updated_at: ^now
      ]
    ]
  )
  |> Repo.update_all([])

  :ok
end
```

- [ ] **Step 4: Run all tests**

```bash
mix test test/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast_test.exs
```

Expected: all tests pass, including the regression test.

- [ ] **Step 5: Run full precommit checks**

```bash
mix precommit
```

Expected: compiles cleanly, all tests pass, format clean.

- [ ] **Step 6: Commit**

```
fix(messaging): replace 100-message dedup ceiling with projection lookup

ReplyPrivatelyToBroadcast now checks system note existence via the
ConversationSummaries projection's JSONB instead of scanning up to
100 messages in-memory. Fixes #431.
```

---

## Chunk 3: Final Verification

### Task 9: Full Integration Verification

- [ ] **Step 1: Run the full test suite**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 2: Verify via Tidewave that the projection works end-to-end**

Use `project_eval` to manually test:

```elixir
# Check that existing conversation summaries have the system_notes column
KlassHero.Repo.all(
  from s in "conversation_summaries",
  select: %{id: s.id, system_notes: s.system_notes},
  limit: 5
)
```

- [ ] **Step 3: Verify the GIN index exists**

Use `execute_sql_query`:

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'conversation_summaries' AND indexname LIKE '%system_notes%';
```

- [ ] **Step 4: Final commit and push**

```bash
git log --oneline -10  # Review commit history
```

Verify the commit chain is clean, then follow the session completion workflow.
