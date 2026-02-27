# CQRS Denormalized Read Models — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Introduce denormalized read tables and event-driven projections for Program Catalog and Messaging, separating read paths from write paths.

**Architecture:** Each context gets a read table (Ecto migration), a projection GenServer (subscribes to integration events, maintains the read table), a read DTO (lightweight struct), a read port (behaviour), and a read repository (adapter). Write paths stay untouched. Follows the existing `VerifiedProviders` projection pattern but persists to Postgres instead of in-memory.

**Tech Stack:** Elixir/Phoenix, Ecto, Phoenix.PubSub, GenServer projections, ExMachina factories

**TDD:** Every task follows red-green-refactor. No production code without a failing test first.

---

## Task 1: Program Catalog — `program_updated` Domain Event

The `UpdateProgram` use case only dispatches `:program_schedule_updated` when scheduling fields change. The projection needs to know about ALL updates (title, price, description, etc.). Add a `:program_updated` domain event that always fires.

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/events/program_events.ex`
- Modify: `lib/klass_hero/program_catalog/application/use_cases/update_program.ex`
- Test: `test/klass_hero/program_catalog/domain/events/program_events_test.exs`
- Test: `test/klass_hero/program_catalog/application/use_cases/update_program_test.exs`

**Step 1: Write failing test for the new event factory function**

```elixir
# test/klass_hero/program_catalog/domain/events/program_events_test.exs
defmodule KlassHero.ProgramCatalog.Domain.Events.ProgramEventsTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Events.ProgramEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "program_updated/3" do
    test "creates a program_updated domain event with payload" do
      program_id = Ecto.UUID.generate()
      payload = %{title: "Updated Title", price: Decimal.new("200.00")}

      event = ProgramEvents.program_updated(program_id, payload)

      assert %DomainEvent{} = event
      assert event.event_type == :program_updated
      assert event.aggregate_id == program_id
      assert event.aggregate_type == :program
      assert event.payload.program_id == program_id
      assert event.payload.title == "Updated Title"
    end

    test "raises on empty program_id" do
      assert_raise ArgumentError, fn ->
        ProgramEvents.program_updated("", %{})
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/program_catalog/domain/events/program_events_test.exs -v`
Expected: FAIL — `program_updated` function not defined

**Step 3: Implement `program_updated` in ProgramEvents**

Add to `lib/klass_hero/program_catalog/domain/events/program_events.ex`:

```elixir
def program_updated(program_id, payload \\ %{}, opts \\ [])

def program_updated(program_id, payload, opts)
    when is_binary(program_id) and byte_size(program_id) > 0 do
  base_payload = %{program_id: program_id}

  DomainEvent.new(
    :program_updated,
    program_id,
    @aggregate_type,
    Map.merge(payload, base_payload),
    opts
  )
end

def program_updated(program_id, _payload, _opts) do
  raise ArgumentError,
        "program_updated/3 requires a non-empty program_id string, got: #{inspect(program_id)}"
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/program_catalog/domain/events/program_events_test.exs -v`
Expected: PASS

**Step 5: Update `UpdateProgram` use case to always dispatch `program_updated`**

Modify `lib/klass_hero/program_catalog/application/use_cases/update_program.ex`:

- Add a `dispatch_update_event/1` that always fires `:program_updated` with the full program payload
- Keep `maybe_dispatch_schedule_event/2` as-is (it serves a different purpose for schedule-specific subscribers)
- Call `dispatch_update_event(persisted)` after the successful update, before `maybe_dispatch_schedule_event`

**Step 6: Register `program_updated` handler on the DomainEventBus**

In `lib/klass_hero/application.ex`, add `:program_updated` to the ProgramCatalog event bus handlers alongside `:program_created`, pointing to the same `PromoteIntegrationEvents` handler.

**Step 7: Commit**

```
feat(program-catalog): add program_updated domain event for CQRS projections
```

---

## Task 2: Program Catalog — `program_updated` Integration Event

Promote the domain event to an integration event for cross-context consumption.

**Files:**
- Modify: `lib/klass_hero/program_catalog/domain/events/program_catalog_integration_events.ex`
- Modify: `lib/klass_hero/program_catalog/adapters/driven/events/event_handlers/promote_integration_events.ex`
- Test: `test/klass_hero/program_catalog/adapters/driven/events/event_handlers/promote_integration_events_test.exs`

**Step 1: Write failing test for integration event promotion**

Add to the existing `PromoteIntegrationEventsTest`:

```elixir
describe "handle/1 — :program_updated" do
  test "promotes to program_updated integration event" do
    program_id = Ecto.UUID.generate()

    domain_event =
      DomainEvent.new(:program_updated, program_id, :program, %{
        provider_id: Ecto.UUID.generate(),
        title: "Updated Title",
        price: "200.00"
      })

    assert :ok = PromoteIntegrationEvents.handle(domain_event)

    event = assert_integration_event_published(:program_updated)
    assert event.entity_id == program_id
    assert event.source_context == :program_catalog
    assert event.payload.title == "Updated Title"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/events/event_handlers/promote_integration_events_test.exs -v`
Expected: FAIL — no matching function clause for `:program_updated`

**Step 3: Add `program_updated` to the integration event factory**

In `program_catalog_integration_events.ex`, add:

```elixir
def program_updated(program_id, payload \\ %{}, opts \\ [])

def program_updated(program_id, payload, opts)
    when is_binary(program_id) and byte_size(program_id) > 0 do
  base_payload = %{program_id: program_id}

  IntegrationEvent.new(
    :program_updated,
    @source_context,
    @entity_type,
    program_id,
    Map.merge(payload, base_payload),
    opts
  )
end

def program_updated(program_id, _payload, _opts) do
  raise ArgumentError,
        "program_updated/3 requires a non-empty program_id string, got: #{inspect(program_id)}"
end
```

**Step 4: Add handler clause in PromoteIntegrationEvents**

```elixir
def handle(%DomainEvent{event_type: :program_updated} = event) do
  result =
    event.aggregate_id
    |> ProgramCatalogIntegrationEvents.program_updated(event.payload)
    |> IntegrationEventPublishing.publish()

  case result do
    :ok -> :ok
    {:error, reason} = error ->
      Logger.warning("[PromoteIntegrationEvents] Failed to publish program_updated",
        program_id: event.aggregate_id,
        reason: inspect(reason)
      )
      error
  end
end
```

**Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/events/event_handlers/promote_integration_events_test.exs -v`
Expected: PASS

**Step 6: Commit**

```
feat(program-catalog): add program_updated integration event promotion
```

---

## Task 3: Messaging — Integration Event Promotions

The Messaging `PromoteIntegrationEvents` handler currently only promotes `user_data_anonymized`. Add promotions for: `conversation_created`, `message_sent`, `messages_read`, `conversation_archived`, `conversations_archived`.

**Files:**
- Modify: `lib/klass_hero/messaging/domain/events/messaging_integration_events.ex`
- Modify: `lib/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events.ex`
- Modify: `lib/klass_hero/application.ex` (register new event types on Messaging bus)
- Test: `test/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events_test.exs`

**Step 1: Write failing tests for all five new integration event factories**

Create/extend test file with tests for each factory function: `conversation_created/3`, `message_sent/3`, `messages_read/3`, `conversation_archived/3`, `conversations_archived/3`. Each test follows the same pattern as the existing `message_data_anonymized` test — construct the event, assert event_type, source_context, entity_id, payload fields.

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events_test.exs -v`
Expected: FAIL — functions not defined

**Step 3: Implement the five factory functions in `MessagingIntegrationEvents`**

Each follows the existing `message_data_anonymized` pattern:
- `conversation_created(conversation_id, payload, opts)` — entity_type: `:conversation`
- `message_sent(conversation_id, payload, opts)` — entity_type: `:conversation`
- `messages_read(conversation_id, payload, opts)` — entity_type: `:conversation`
- `conversation_archived(conversation_id, payload, opts)` — entity_type: `:conversation`
- `conversations_archived(aggregate_id, payload, opts)` — entity_type: `:conversation`

**Step 4: Implement handler clauses in Messaging PromoteIntegrationEvents**

Add `handle/1` clauses for each event type. Follow the same error-logging pattern as the ProgramCatalog handler — return `{:error, reason}` for `conversation_created` and `message_sent` (important events), return `:ok` on failure for less critical ones like `messages_read`.

**Step 5: Register new event types on the Messaging DomainEventBus in `application.ex`**

Add entries for `:conversation_created`, `:message_sent`, `:messages_read`, `:conversation_archived`, `:conversations_archived` pointing to the Messaging `PromoteIntegrationEvents` handler at priority 10.

**Step 6: Run tests to verify they pass**

Run: `mix test test/klass_hero/messaging/adapters/driven/events/event_handlers/promote_integration_events_test.exs -v`
Expected: PASS

**Step 7: Run full test suite**

Run: `mix test`
Expected: All green

**Step 8: Commit**

```
feat(messaging): add integration event promotions for CQRS projections

Adds conversation_created, message_sent, messages_read,
conversation_archived, conversations_archived integration events.
```

---

## Task 4: `program_listings` Migration

**Files:**
- Create: `priv/repo/migrations/20260226000012_create_program_listings.exs`

**Step 1: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.CreateProgramListings do
  use Ecto.Migration

  def up do
    create table(:program_listings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :category, :string
      add :age_range, :string
      add :price, :decimal
      add :pricing_period, :string
      add :location, :string
      add :cover_image_url, :string
      add :icon_path, :string
      add :instructor_name, :string
      add :instructor_headshot_url, :string
      add :start_date, :date
      add :end_date, :date
      add :meeting_days, {:array, :string}, default: []
      add :meeting_start_time, :time
      add :meeting_end_time, :time
      add :season, :string
      add :registration_start_date, :date
      add :registration_end_date, :date
      add :provider_id, :binary_id, null: false
      add :provider_verified, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:program_listings, [:inserted_at, :id], name: :program_listings_cursor_idx)
    create index(:program_listings, [:category])
    create index(:program_listings, [:provider_id])
  end

  def down do
    drop table(:program_listings)
  end
end
```

**Step 2: Run migration**

Run: `mix ecto.migrate`
Expected: Migration completes successfully

**Step 3: Verify in test DB too**

Run: `MIX_ENV=test mix ecto.migrate`
Expected: Migration completes

**Step 4: Commit**

```
feat(program-catalog): add program_listings read model table
```

---

## Task 5: `conversation_summaries` Migration

**Files:**
- Create: `priv/repo/migrations/20260226000013_create_conversation_summaries.exs`

**Step 1: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.CreateConversationSummaries do
  use Ecto.Migration

  def up do
    create table(:conversation_summaries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conversation_id, :binary_id, null: false
      add :user_id, :binary_id, null: false
      add :conversation_type, :string, null: false
      add :provider_id, :binary_id, null: false
      add :program_id, :binary_id
      add :subject, :string
      add :other_participant_name, :string
      add :participant_count, :integer, default: 0
      add :latest_message_content, :text
      add :latest_message_sender_id, :binary_id
      add :latest_message_at, :utc_datetime
      add :unread_count, :integer, default: 0, null: false
      add :last_read_at, :utc_datetime
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:conversation_summaries, [:conversation_id, :user_id])
    create index(:conversation_summaries, [:user_id, :archived_at, :latest_message_at],
             name: :conversation_summaries_inbox_idx)
    create index(:conversation_summaries, [:conversation_id])

    execute """
    CREATE INDEX conversation_summaries_unread_idx
    ON conversation_summaries (user_id)
    WHERE archived_at IS NULL
    """
  end

  def down do
    drop table(:conversation_summaries)
  end
end
```

**Step 2: Run migration**

Run: `mix ecto.migrate && MIX_ENV=test mix ecto.migrate`
Expected: Both succeed

**Step 3: Commit**

```
feat(messaging): add conversation_summaries read model table
```

---

## Task 6: Program Catalog — Read DTO and Ecto Schema

**Files:**
- Create: `lib/klass_hero/program_catalog/domain/read_models/program_listing.ex`
- Create: `lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_listing_schema.ex`
- Test: `test/klass_hero/program_catalog/domain/read_models/program_listing_test.exs`

**Step 1: Write failing test for the read DTO**

```elixir
defmodule KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListingTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing

  describe "new/1" do
    test "creates a ProgramListing from a map of attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        title: "Soccer Camp",
        category: "sports",
        price: Decimal.new("150.00"),
        provider_id: Ecto.UUID.generate(),
        provider_verified: true,
        instructor_name: "Jane Smith",
        inserted_at: ~U[2026-01-01 12:00:00Z]
      }

      listing = ProgramListing.new(attrs)

      assert listing.id == attrs.id
      assert listing.title == "Soccer Camp"
      assert listing.provider_verified == true
      assert listing.instructor_name == "Jane Smith"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/program_catalog/domain/read_models/program_listing_test.exs -v`
Expected: FAIL — module not found

**Step 3: Implement ProgramListing read DTO**

```elixir
# lib/klass_hero/program_catalog/domain/read_models/program_listing.ex
defmodule KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing do
  @moduledoc """
  Read-optimized DTO for program listings.

  Lightweight struct for display — no business logic, no value objects.
  Populated from the denormalized program_listings read table.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          description: String.t() | nil,
          category: String.t() | nil,
          age_range: String.t() | nil,
          price: Decimal.t() | nil,
          pricing_period: String.t() | nil,
          location: String.t() | nil,
          cover_image_url: String.t() | nil,
          icon_path: String.t() | nil,
          instructor_name: String.t() | nil,
          instructor_headshot_url: String.t() | nil,
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          meeting_days: [String.t()],
          meeting_start_time: Time.t() | nil,
          meeting_end_time: Time.t() | nil,
          season: String.t() | nil,
          registration_start_date: Date.t() | nil,
          registration_end_date: Date.t() | nil,
          provider_id: String.t(),
          provider_verified: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :title,
    :description,
    :category,
    :age_range,
    :price,
    :pricing_period,
    :location,
    :cover_image_url,
    :icon_path,
    :instructor_name,
    :instructor_headshot_url,
    :start_date,
    :end_date,
    :meeting_start_time,
    :meeting_end_time,
    :season,
    :registration_start_date,
    :registration_end_date,
    :provider_id,
    :inserted_at,
    :updated_at,
    meeting_days: [],
    provider_verified: false
  ]

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end
end
```

**Step 4: Implement ProgramListingSchema (Ecto schema for the read table)**

```elixir
# lib/klass_hero/program_catalog/adapters/driven/persistence/schemas/program_listing_schema.ex
defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema do
  @moduledoc """
  Ecto schema for the program_listings read model table.

  This schema is write-only from the projection's perspective and
  read-only from the repository's perspective. No changesets for
  user-facing validation — the projection controls all writes.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "program_listings" do
    field :title, :string
    field :description, :string
    field :category, :string
    field :age_range, :string
    field :price, :decimal
    field :pricing_period, :string
    field :location, :string
    field :cover_image_url, :string
    field :icon_path, :string
    field :instructor_name, :string
    field :instructor_headshot_url, :string
    field :start_date, :date
    field :end_date, :date
    field :meeting_days, {:array, :string}, default: []
    field :meeting_start_time, :time
    field :meeting_end_time, :time
    field :season, :string
    field :registration_start_date, :date
    field :registration_end_date, :date
    field :provider_id, :binary_id
    field :provider_verified, :boolean, default: false

    timestamps(type: :utc_datetime)
  end
end
```

**Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/program_catalog/domain/read_models/program_listing_test.exs -v`
Expected: PASS

**Step 6: Commit**

```
feat(program-catalog): add ProgramListing read DTO and Ecto schema
```

---

## Task 7: Messaging — Read DTO and Ecto Schema

Same pattern as Task 6 but for `ConversationSummary`.

**Files:**
- Create: `lib/klass_hero/messaging/domain/read_models/conversation_summary.ex`
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/conversation_summary_schema.ex`
- Test: `test/klass_hero/messaging/domain/read_models/conversation_summary_test.exs`

**Step 1: Write failing test for ConversationSummary DTO**

```elixir
defmodule KlassHero.Messaging.Domain.ReadModels.ConversationSummaryTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.ReadModels.ConversationSummary

  describe "new/1" do
    test "creates a ConversationSummary from attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        conversation_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        conversation_type: "direct",
        provider_id: Ecto.UUID.generate(),
        other_participant_name: "Jane Smith",
        unread_count: 3,
        latest_message_content: "Hello!",
        latest_message_at: ~U[2026-02-26 10:00:00Z]
      }

      summary = ConversationSummary.new(attrs)

      assert summary.conversation_id == attrs.conversation_id
      assert summary.unread_count == 3
      assert summary.other_participant_name == "Jane Smith"
    end
  end
end
```

**Step 2: Run test, verify fail, implement, verify pass** — same cycle as Task 6.

The `ConversationSummary` struct has fields: `id`, `conversation_id`, `user_id`, `conversation_type`, `provider_id`, `program_id`, `subject`, `other_participant_name`, `participant_count`, `latest_message_content`, `latest_message_sender_id`, `latest_message_at`, `unread_count`, `last_read_at`, `archived_at`, `inserted_at`, `updated_at`.

The `ConversationSummarySchema` mirrors the `conversation_summaries` table exactly.

**Step 3: Commit**

```
feat(messaging): add ConversationSummary read DTO and Ecto schema
```

---

## Task 8: Program Catalog — Read Port and Repository

**Files:**
- Create: `lib/klass_hero/program_catalog/domain/ports/for_listing_program_summaries.ex`
- Create: `lib/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_listings_repository.ex`
- Modify: `config/config.exs` (add `:for_listing_program_summaries` to `:program_catalog` config)
- Test: `test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_listings_repository_test.exs`

**Step 1: Define the read port**

```elixir
# lib/klass_hero/program_catalog/domain/ports/for_listing_program_summaries.ex
defmodule KlassHero.ProgramCatalog.Domain.Ports.ForListingProgramSummaries do
  @moduledoc """
  Read port for querying the program_listings denormalized read model.

  Implemented by the ProgramListingsRepository adapter.
  """

  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHero.Shared.Domain.Types.Pagination.PageResult

  @callback list_paginated(limit :: pos_integer(), cursor :: binary() | nil, category :: String.t() | nil) ::
              {:ok, %PageResult{}} | {:error, :invalid_cursor}

  @callback list_for_provider(provider_id :: String.t()) :: [ProgramListing.t()]

  @callback get_by_id(id :: binary()) :: {:ok, ProgramListing.t()} | {:error, :not_found}
end
```

**Step 2: Write failing repository tests**

```elixir
# test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_listings_repository_test.exs
defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramListingsRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramListingsRepository
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHero.Repo

  defp insert_listing(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    defaults = %{
      id: Ecto.UUID.generate(),
      title: "Test Program",
      provider_id: Ecto.UUID.generate(),
      provider_verified: false,
      meeting_days: [],
      inserted_at: now,
      updated_at: now
    }
    merged = Map.merge(defaults, attrs)
    Repo.insert!(struct(ProgramListingSchema, merged))
  end

  describe "list_paginated/3" do
    test "returns programs as ProgramListing DTOs" do
      insert_listing(%{title: "Soccer Camp", category: "sports"})

      {:ok, page} = ProgramListingsRepository.list_paginated(10, nil, nil)

      assert length(page.items) >= 1
      assert Enum.all?(page.items, &match?(%ProgramListing{}, &1))
    end

    test "filters by category" do
      insert_listing(%{title: "Soccer", category: "sports"})
      insert_listing(%{title: "Math", category: "education"})

      {:ok, page} = ProgramListingsRepository.list_paginated(10, nil, "sports")

      titles = Enum.map(page.items, & &1.title)
      assert "Soccer" in titles
      refute "Math" in titles
    end
  end

  describe "get_by_id/1" do
    test "returns a ProgramListing for an existing id" do
      listing = insert_listing(%{title: "Art Class"})

      assert {:ok, %ProgramListing{title: "Art Class"}} =
               ProgramListingsRepository.get_by_id(listing.id)
    end

    test "returns :not_found for missing id" do
      assert {:error, :not_found} =
               ProgramListingsRepository.get_by_id(Ecto.UUID.generate())
    end
  end
end
```

**Step 3: Run tests, verify fail**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_listings_repository_test.exs -v`
Expected: FAIL — module not found

**Step 4: Implement ProgramListingsRepository**

The repository queries `ProgramListingSchema`, converts results to `ProgramListing` DTOs via `struct!`. Uses the same cursor-based pagination pattern as the existing `ProgramRepository` (base64 JSON encoding of `{inserted_at, id}`).

**Step 5: Add to config**

In `config/config.exs` under `:program_catalog`:

```elixir
config :klass_hero, :program_catalog,
  repository: ...,  # existing
  for_listing_program_summaries:
    KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramListingsRepository
```

**Step 6: Run tests, verify pass**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/persistence/repositories/program_listings_repository_test.exs -v`
Expected: PASS

**Step 7: Commit**

```
feat(program-catalog): add read port and ProgramListingsRepository
```

---

## Task 9: Messaging — Read Port and Repository

**Files:**
- Create: `lib/klass_hero/messaging/domain/ports/for_listing_conversation_summaries.ex`
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository.ex`
- Modify: `config/config.exs` (add to `:messaging` config)
- Test: `test/klass_hero/messaging/adapters/driven/persistence/repositories/conversation_summaries_repository_test.exs`

**Step 1: Define the read port**

```elixir
defmodule KlassHero.Messaging.Domain.Ports.ForListingConversationSummaries do
  alias KlassHero.Messaging.Domain.ReadModels.ConversationSummary

  @callback list_for_user(user_id :: String.t(), opts :: keyword()) ::
              {:ok, [ConversationSummary.t()], has_more :: boolean()}

  @callback get_total_unread_count(user_id :: String.t()) :: non_neg_integer()
end
```

**Step 2: Write failing tests**

Test `list_for_user/2`:
- Returns ConversationSummary DTOs for a user
- Orders by `latest_message_at` DESC
- Excludes archived conversations
- Paginates with limit

Test `get_total_unread_count/1`:
- Sums unread_count across active conversations
- Ignores archived conversations

**Step 3: Run tests, verify fail, implement, verify pass**

The repository queries `ConversationSummarySchema`, converts to `ConversationSummary` DTOs. Simple `WHERE user_id = ? AND archived_at IS NULL ORDER BY latest_message_at DESC` query. Total unread is `SELECT COALESCE(SUM(unread_count), 0) WHERE user_id = ? AND archived_at IS NULL`.

**Step 4: Add to config and Messaging `Repositories` module**

Add `:for_listing_conversation_summaries` to the `:messaging` config. Add a `conversation_summaries/0` accessor to `KlassHero.Messaging.Repositories`.

**Step 5: Commit**

```
feat(messaging): add read port and ConversationSummariesRepository
```

---

## Task 10: Program Catalog — ProgramListingsProjection

The core projection GenServer that keeps `program_listings` in sync.

**Files:**
- Create: `lib/klass_hero/program_catalog/adapters/driven/projections/program_listings.ex`
- Modify: `lib/klass_hero/application.ex` (add to projections list)
- Test: `test/klass_hero/program_catalog/adapters/driven/projections/program_listings_test.exs`

**Step 1: Write failing tests**

Follow the `VerifiedProvidersTest` pattern — use a unique GenServer name per test, start with `start_supervised!`, broadcast events via PubSub, synchronize with `:sys.get_state/1`.

```elixir
defmodule KlassHero.ProgramCatalog.Adapters.Driven.Projections.ProgramListingsTest do
  use KlassHero.DataCase, async: false

  import KlassHero.Factory

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProgramCatalog.Adapters.Driven.Projections.ProgramListings
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @test_server_name :program_listings_test

  setup do
    start_supervised!({ProgramListings, name: @test_server_name})
    :ok
  end

  describe "bootstrap" do
    test "populates program_listings from programs table on startup" do
      # Insert program into write table BEFORE starting projection
      stop_supervised!(ProgramListings)
      _program = insert(:program_schema, title: "Soccer Camp", category: "sports")
      start_supervised!({ProgramListings, name: @test_server_name})

      # Synchronize
      _ = :sys.get_state(@test_server_name)

      listings = Repo.all(ProgramListingSchema)
      assert length(listings) >= 1
      assert Enum.any?(listings, &(&1.title == "Soccer Camp"))
    end
  end

  describe "handle program_created event" do
    test "inserts a new row into program_listings" do
      program_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()

      event = IntegrationEvent.new(
        :program_created,
        :program_catalog,
        :program,
        program_id,
        %{
          program_id: program_id,
          provider_id: provider_id,
          title: "New Art Class",
          category: "arts",
          price: "75.00"
        }
      )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:program_catalog:program_created",
        {:integration_event, event}
      )

      _ = :sys.get_state(@test_server_name)

      listing = Repo.get(ProgramListingSchema, program_id)
      assert listing != nil
      assert listing.title == "New Art Class"
    end
  end

  describe "handle program_updated event" do
    test "updates existing row in program_listings" do
      # Setup: insert a listing first
      program_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Repo.insert!(%ProgramListingSchema{
        id: program_id,
        title: "Old Title",
        provider_id: Ecto.UUID.generate(),
        inserted_at: now,
        updated_at: now
      })

      event = IntegrationEvent.new(
        :program_updated,
        :program_catalog,
        :program,
        program_id,
        %{program_id: program_id, title: "New Title", price: "200.00"}
      )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:program_catalog:program_updated",
        {:integration_event, event}
      )

      _ = :sys.get_state(@test_server_name)

      listing = Repo.get(ProgramListingSchema, program_id)
      assert listing.title == "New Title"
    end
  end

  describe "handle provider_verified event" do
    test "sets provider_verified to true for all provider's programs" do
      provider_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Repo.insert!(%ProgramListingSchema{
        id: Ecto.UUID.generate(),
        title: "Program A",
        provider_id: provider_id,
        provider_verified: false,
        inserted_at: now,
        updated_at: now
      })

      event = IntegrationEvent.new(
        :provider_verified,
        :provider,
        :provider,
        provider_id,
        %{provider_id: provider_id}
      )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:provider:provider_verified",
        {:integration_event, event}
      )

      _ = :sys.get_state(@test_server_name)

      [listing] = Repo.all(from l in ProgramListingSchema, where: l.provider_id == ^provider_id)
      assert listing.provider_verified == true
    end
  end
end
```

**Step 2: Run tests, verify fail**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/projections/program_listings_test.exs -v`
Expected: FAIL — module not found

**Step 3: Implement ProgramListingsProjection GenServer**

```elixir
# lib/klass_hero/program_catalog/adapters/driven/projections/program_listings.ex
defmodule KlassHero.ProgramCatalog.Adapters.Driven.Projections.ProgramListings do
  use GenServer

  # Subscribes to integration events, maintains program_listings read table.
  # Bootstrap rebuilds from programs write table on startup.

  # Topics:
  # - integration:program_catalog:program_created
  # - integration:program_catalog:program_updated
  # - integration:provider:provider_verified
  # - integration:provider:provider_unverified

  # GenServer callbacks: init → subscribe + {:continue, :bootstrap}
  # handle_continue(:bootstrap) → query programs table, upsert all into program_listings
  # handle_info({:integration_event, event}) → dispatch to handle_event/1
  # handle_event/1 → pattern match on event_type, upsert/update program_listings

  # Bootstrap queries the ProgramSchema table, maps each row to ProgramListingSchema attrs
  # (flattening instructor fields, looking up provider_verified from VerifiedProviders),
  # and does Repo.insert_all with on_conflict: :replace_all.
end
```

Key implementation details:
- Bootstrap uses `Repo.insert_all` with `on_conflict: :replace_all` and `conflict_target: :id` for idempotent full rebuild
- `program_created` handler does `Repo.insert` with the event payload fields
- `program_updated` handler does `Repo.get + Ecto.Changeset.change + Repo.update`
- `provider_verified/unverified` handlers do `Repo.update_all` on `WHERE provider_id = ?`

**Step 4: Add to application.ex projections list**

Add `KlassHero.ProgramCatalog.Adapters.Driven.Projections.ProgramListings` to the `in_memory_projections/0` function alongside `VerifiedProviders`.

**Step 5: Run tests, verify pass**

Run: `mix test test/klass_hero/program_catalog/adapters/driven/projections/program_listings_test.exs -v`
Expected: PASS

**Step 6: Run full test suite**

Run: `mix test`
Expected: All green (projections skipped in test env via `start_projections: false`)

**Step 7: Commit**

```
feat(program-catalog): add ProgramListingsProjection GenServer

Event-driven projection maintaining the program_listings read table.
Bootstraps from write table, syncs via integration events.
```

---

## Task 11: Messaging — ConversationSummariesProjection

**Files:**
- Create: `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex`
- Modify: `lib/klass_hero/application.ex` (add to projections list)
- Test: `test/klass_hero/messaging/adapters/driven/projections/conversation_summaries_test.exs`

**Step 1: Write failing tests**

Follow same pattern as Task 10. Key test cases:

- **Bootstrap:** Insert conversations + participants + messages into write tables, start projection, verify `conversation_summaries` rows exist with correct `unread_count`, `latest_message_content`, `other_participant_name`
- **conversation_created:** Broadcast event → verify one row per participant
- **message_sent:** Broadcast event → verify `latest_message_*` updated, `unread_count` incremented for non-sender participants
- **messages_read:** Broadcast event → verify `unread_count` set to 0 and `last_read_at` updated for that user
- **conversation_archived:** Broadcast event → verify `archived_at` set

**Step 2: Run tests, verify fail**

Expected: FAIL — module not found

**Step 3: Implement ConversationSummariesProjection**

Subscribes to:
- `integration:messaging:conversation_created`
- `integration:messaging:message_sent`
- `integration:messaging:messages_read`
- `integration:messaging:conversation_archived`
- `integration:messaging:conversations_archived`
- `integration:messaging:message_data_anonymized`

Bootstrap queries `conversations` + `participants` + `messages` to build all rows. For each conversation, for each active participant, compute `unread_count` (messages after `last_read_at`), find `latest_message`, resolve `other_participant_name` from the users table.

Event handlers:
- `conversation_created`: Insert one row per participant. For direct convos, resolve display names.
- `message_sent`: Update all rows for that `conversation_id` — set `latest_message_*` fields, increment `unread_count` for all `user_id != sender_id`.
- `messages_read`: Update the row for `{conversation_id, user_id}` — set `unread_count = 0`, update `last_read_at`.
- `conversation_archived`: Update all rows for that `conversation_id` — set `archived_at`.
- `conversations_archived`: Same but bulk.
- `message_data_anonymized`: Update `other_participant_name` to "Deleted User" where it referred to the anonymized user.

**Step 4: Add to application.ex projections list**

**Step 5: Run tests, verify pass, run full suite**

**Step 6: Commit**

```
feat(messaging): add ConversationSummariesProjection GenServer

Event-driven projection maintaining conversation_summaries read table.
Bootstraps from write tables, syncs via integration events.
```

---

## Task 12: Switch Read Use Cases to Read Models

The final wiring — point existing read use cases at the new read repositories.

**Files:**
- Modify: `lib/klass_hero/program_catalog/application/use_cases/list_programs_paginated.ex`
- Modify: `lib/klass_hero/program_catalog/application/use_cases/list_all_programs.ex`
- Modify: `lib/klass_hero/program_catalog/application/use_cases/list_provider_programs.ex`
- Modify: `lib/klass_hero/program_catalog/application/use_cases/list_featured_programs.ex`
- Modify: `lib/klass_hero/messaging/application/use_cases/list_conversations.ex`
- Modify: `lib/klass_hero/messaging/application/use_cases/get_total_unread_count.ex`
- Tests: Update existing use case tests to account for read DTOs in return values

**Step 1: Update Program Catalog read use cases**

Change `ListProgramsPaginated` to call the configured `for_listing_program_summaries` repository instead of `ProgramRepository`. It now returns `ProgramListing` DTOs instead of `Program` domain entities.

Similarly for `ListAllPrograms`, `ListProviderPrograms`, `ListFeaturedPrograms`.

**Step 2: Update Messaging read use cases**

Replace the multi-query enrichment in `ListConversations` with a single call to the conversation summaries repository. The new implementation is dramatically simpler — no more `collect_other_participant_ids`, `enrich_conversation`, separate participant/message queries.

Replace `GetTotalUnreadCount` to call `conversation_summaries_repository.get_total_unread_count(user_id)`.

**Step 3: Update tests**

Existing use case tests that assert on `%Program{}` structs need to assert on `%ProgramListing{}` instead. Tests that mock the repository need to mock the new read port.

**Step 4: Run full test suite**

Run: `mix test`
Expected: All green

**Step 5: Commit**

```
feat: switch read use cases to CQRS read models

Program listing and conversation listing use cases now query
denormalized read tables instead of write tables.
```

---

## Task 13: Factory Additions

Add ExMachina factories for the new schemas to support future tests.

**Files:**
- Modify: `test/support/factory.ex`

Add:
- `program_listing_schema_factory` — builds `ProgramListingSchema` with sensible defaults
- `conversation_summary_schema_factory` — builds `ConversationSummarySchema` with sensible defaults

**Commit:**

```
test: add factories for CQRS read model schemas
```

---

## Task 14: Precommit and Full Verification

**Step 1: Run precommit checks**

Run: `mix precommit`
Expected: Compile with `--warnings-as-errors` passes, format passes, all tests pass

**Step 2: Fix any warnings or test failures**

**Step 3: Final commit if needed**

---

## Execution Order Summary

| Task | What | Depends On |
|------|------|-----------|
| 1 | `program_updated` domain event | — |
| 2 | `program_updated` integration event | Task 1 |
| 3 | Messaging integration event promotions | — |
| 4 | `program_listings` migration | — |
| 5 | `conversation_summaries` migration | — |
| 6 | ProgramListing DTO + schema | Task 4 |
| 7 | ConversationSummary DTO + schema | Task 5 |
| 8 | Program read port + repository | Task 6 |
| 9 | Messaging read port + repository | Task 7 |
| 10 | ProgramListingsProjection | Tasks 2, 4, 6 |
| 11 | ConversationSummariesProjection | Tasks 3, 5, 7 |
| 12 | Switch read use cases | Tasks 8, 9, 10, 11 |
| 13 | Factory additions | Tasks 6, 7 |
| 14 | Precommit verification | All above |

**Parallelizable groups:**
- Tasks 1+3+4+5 (independent foundations)
- Tasks 6+7 (after migrations)
- Tasks 8+9 (after DTOs)
- Tasks 10+11 (after events + DTOs + migrations)
