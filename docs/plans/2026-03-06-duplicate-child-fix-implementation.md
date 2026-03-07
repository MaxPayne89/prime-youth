# Fix #299: Duplicate Child on Parent Profile — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Use superpowers:test-driven-development strictly — no production code without a failing test first.

**Goal:** Prevent duplicate children when the same child is enrolled in multiple programs via provider CSV import, and remediate existing duplicates in production.

**Architecture:** Extract invite-claim processing into a dedicated use case (`ProcessInviteClaim`), called by a new Oban worker with per-parent uniqueness. The existing `InviteClaimedHandler` becomes a thin enqueue adapter. A one-off script merges existing duplicate children in production.

**Tech Stack:** Elixir, Oban (unique jobs), Ecto, PostgreSQL

**TDD Discipline:** Every task follows RED → verify fail → GREEN → verify pass → REFACTOR. No production code without a failing test first.

---

### Task 1: Add `family` Oban Queue

Config-only change — TDD exception (configuration).

**Files:**
- Modify: `config/config.exs:61`

**Step 1: Add the queue**

Change line 61 from:
```elixir
  queues: [default: 10, messaging: 5, cleanup: 2, email: 5]
```
to:
```elixir
  queues: [default: 10, messaging: 5, cleanup: 2, email: 5, family: 5]
```

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Success

**Step 3: Commit**

```bash
git add config/config.exs
git commit -m "config: add family Oban queue for invite processing"
```

---

### Task 2: Create `ProcessInviteClaim` Use Case (TDD)

Domain logic extracted from `InviteClaimedHandler`. Orchestrates: ensure parent profile → find-or-create child → publish `invite_family_ready`.

**Files:**
- Test: `test/klass_hero/family/application/use_cases/invites/process_invite_claim_test.exs`
- Create: `lib/klass_hero/family/application/use_cases/invites/process_invite_claim.ex`

**Reference files:**
- Existing handler (logic source): `lib/klass_hero/family/adapters/driven/events/invite_claimed_handler.ex`
- CreateChild use case (pattern): `lib/klass_hero/family/application/use_cases/children/create_child.ex`
- Family public API: `lib/klass_hero/family.ex`
- FamilyEvents: `lib/klass_hero/family/domain/events/family_events.ex`

#### Cycle 1: Creates parent profile and child for new user

**RED — Write failing test**

Create the test file with a single test:

```elixir
defmodule KlassHero.Family.Application.UseCases.Invites.ProcessInviteClaimTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Family
  alias KlassHero.Family.Application.UseCases.Invites.ProcessInviteClaim

  defp valid_attrs(user_id, overrides \\ %{}) do
    Map.merge(
      %{
        invite_id: Ecto.UUID.generate(),
        user_id: user_id,
        program_id: Ecto.UUID.generate(),
        child_first_name: "Emma",
        child_last_name: "Schmidt",
        child_date_of_birth: ~D[2016-03-15],
        school_grade: 3,
        school_name: "Berlin Elementary",
        medical_conditions: "Asthma",
        nut_allergy: true
      },
      overrides
    )
  end

  describe "execute/1" do
    test "creates parent profile and child for new user" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      assert {:ok, %{child: child, parent: parent}} = ProcessInviteClaim.execute(attrs)

      assert child.first_name == "Emma"
      assert child.last_name == "Schmidt"
      assert child.date_of_birth == ~D[2016-03-15]
      assert child.school_grade == 3
      assert child.school_name == "Berlin Elementary"
      assert child.support_needs == "Asthma"
      assert child.allergies == "Nut allergy"
      assert Family.child_belongs_to_parent?(child.id, parent.id)
    end
  end
end
```

**Verify RED**

Run: `mix test test/klass_hero/family/application/use_cases/invites/process_invite_claim_test.exs`
Expected: Compilation error — `ProcessInviteClaim` module does not exist

**GREEN — Write minimal implementation**

Create `lib/klass_hero/family/application/use_cases/invites/process_invite_claim.ex`:

```elixir
defmodule KlassHero.Family.Application.UseCases.Invites.ProcessInviteClaim do
  @moduledoc """
  Use case for processing an invite claim into a family unit.

  Orchestrates: ensure parent profile, find-or-create child, publish
  `invite_family_ready` event. Called by the Oban worker, which serializes
  execution per parent to prevent duplicate children.
  """

  alias KlassHero.Family
  alias KlassHero.Family.Domain.Events.FamilyEvents
  alias KlassHero.Shared.EventDispatchHelper

  require Logger

  def execute(attrs) when is_map(attrs) do
    user_id = Map.fetch!(attrs, :user_id)
    invite_id = Map.fetch!(attrs, :invite_id)
    program_id = Map.fetch!(attrs, :program_id)

    with {:ok, parent} <- ensure_parent_profile(user_id, invite_id),
         {:ok, child} <- find_or_create_child(parent.id, attrs, invite_id, user_id),
         :ok <- publish_family_ready(invite_id, user_id, child.id, parent.id, program_id) do
      {:ok, %{parent: parent, child: child}}
    else
      {:error, reason} ->
        Logger.error("[ProcessInviteClaim] Failed",
          invite_id: invite_id,
          user_id: user_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Trigger: user may already have a parent profile from a prior invite or registration
  # Why: idempotent — create if missing, fetch if exists
  # Outcome: always returns {:ok, parent} or propagates unexpected error
  defp ensure_parent_profile(user_id, invite_id) do
    case Family.create_parent_profile(%{identity_id: user_id}) do
      {:ok, parent} ->
        {:ok, parent}

      {:error, :duplicate_resource} ->
        Family.get_parent_by_identity(user_id)

      {:error, reason} ->
        Logger.error("[ProcessInviteClaim] Failed to create parent profile",
          invite_id: invite_id,
          user_id: user_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Trigger: invite payload contains child data mapped to domain fields
  # Why: same child may be enrolled in multiple programs — avoid duplicates
  # Outcome: child found (idempotent) or created and linked to parent
  defp find_or_create_child(parent_id, attrs, invite_id, user_id) do
    first_name = Map.get(attrs, :child_first_name)
    last_name = Map.get(attrs, :child_last_name)
    date_of_birth = Map.get(attrs, :child_date_of_birth)

    case find_existing_child(parent_id, first_name, last_name, date_of_birth) do
      %{} = child ->
        Logger.info("[ProcessInviteClaim] Child already exists, skipping creation",
          invite_id: invite_id,
          child_id: child.id,
          parent_id: parent_id
        )

        {:ok, child}

      nil ->
        child_attrs = %{
          parent_id: parent_id,
          first_name: first_name,
          last_name: last_name,
          date_of_birth: date_of_birth,
          school_grade: Map.get(attrs, :school_grade),
          school_name: Map.get(attrs, :school_name),
          support_needs: Map.get(attrs, :medical_conditions),
          allergies: map_nut_allergy(Map.get(attrs, :nut_allergy, false))
        }

        case Family.create_child(child_attrs) do
          {:ok, child} ->
            {:ok, child}

          {:error, reason} ->
            Logger.error("[ProcessInviteClaim] Failed to create child",
              invite_id: invite_id,
              user_id: user_id,
              parent_id: parent_id,
              reason: inspect(reason)
            )

            {:error, reason}
        end
    end
  end

  defp find_existing_child(parent_id, first_name, last_name, date_of_birth) do
    parent_id
    |> Family.get_children()
    |> Enum.find(fn child ->
      child.first_name == first_name &&
        child.last_name == last_name &&
        child.date_of_birth == date_of_birth
    end)
  end

  # Trigger: nut_allergy boolean from invite → human-readable string
  # Why: Child.allergies is a free-text field, not a boolean
  # Outcome: true → "Nut allergy", false/nil → nil
  defp map_nut_allergy(true), do: "Nut allergy"
  defp map_nut_allergy(_), do: nil

  defp publish_family_ready(invite_id, user_id, child_id, parent_id, program_id) do
    FamilyEvents.invite_family_ready(invite_id, %{
      invite_id: invite_id,
      user_id: user_id,
      child_id: child_id,
      parent_id: parent_id,
      program_id: program_id
    })
    |> EventDispatchHelper.dispatch_or_error(KlassHero.Family)
  end
end
```

**Verify GREEN**

Run: `mix test test/klass_hero/family/application/use_cases/invites/process_invite_claim_test.exs`
Expected: 1 test, 0 failures

#### Cycle 2: Reuses existing parent profile

**RED**

Add to the `describe "execute/1"` block:

```elixir
    test "reuses existing parent profile" do
      user = user_fixture()
      {:ok, existing_parent} = Family.create_parent_profile(%{identity_id: user.id})
      attrs = valid_attrs(user.id)

      assert {:ok, %{parent: parent}} = ProcessInviteClaim.execute(attrs)
      assert parent.id == existing_parent.id
    end
```

**Verify RED**

Run: `mix test test/klass_hero/family/application/use_cases/invites/process_invite_claim_test.exs`
Expected: Should already pass (the implementation handles `:duplicate_resource`). If it passes immediately, this confirms the existing logic works — move to next cycle.

#### Cycle 3: Idempotent — reuses existing child with same name and DOB

This is the **core bug fix behavior**.

**RED**

Add to the `describe "execute/1"` block:

```elixir
    test "reuses existing child with same name and DOB (idempotent)" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      assert {:ok, %{child: first_child}} = ProcessInviteClaim.execute(attrs)

      # Second call with different program but same child data
      attrs2 =
        valid_attrs(user.id, %{
          invite_id: Ecto.UUID.generate(),
          program_id: Ecto.UUID.generate()
        })

      assert {:ok, %{child: second_child}} = ProcessInviteClaim.execute(attrs2)
      assert second_child.id == first_child.id

      # Only one child exists for this parent
      {:ok, parent} = Family.get_parent_by_identity(user.id)
      assert length(Family.get_children(parent.id)) == 1
    end
```

**Verify RED**

Run: `mix test test/klass_hero/family/application/use_cases/invites/process_invite_claim_test.exs`
Expected: Should pass (find_existing_child logic handles this). This test documents the critical behavior — it proves the dedup works when calls are serialized.

#### Cycle 4: Creates separate children when names differ

**RED**

```elixir
    test "creates separate children when names differ" do
      user = user_fixture()
      attrs1 = valid_attrs(user.id)

      attrs2 =
        valid_attrs(user.id, %{
          invite_id: Ecto.UUID.generate(),
          program_id: Ecto.UUID.generate(),
          child_first_name: "Liam",
          child_date_of_birth: ~D[2018-07-01]
        })

      assert {:ok, %{child: child1}} = ProcessInviteClaim.execute(attrs1)
      assert {:ok, %{child: child2}} = ProcessInviteClaim.execute(attrs2)
      assert child1.id != child2.id
    end
```

**Verify RED** → should pass. Documents boundary behavior.

#### Cycle 5: Maps nut_allergy false to nil

**RED**

```elixir
    test "maps nut_allergy false to nil allergies" do
      user = user_fixture()
      attrs = valid_attrs(user.id, %{nut_allergy: false})

      assert {:ok, %{child: child}} = ProcessInviteClaim.execute(attrs)
      assert is_nil(child.allergies)
    end
```

**Verify RED** → should pass.

#### Cycle 6: Handles nil optional fields

**RED**

```elixir
    test "handles nil optional fields" do
      user = user_fixture()

      attrs =
        valid_attrs(user.id, %{
          school_grade: nil,
          school_name: nil,
          medical_conditions: nil,
          nut_allergy: false
        })

      assert {:ok, %{child: child}} = ProcessInviteClaim.execute(attrs)
      assert is_nil(child.school_grade)
      assert is_nil(child.school_name)
      assert is_nil(child.support_needs)
      assert is_nil(child.allergies)
    end
```

**Verify GREEN** — all 6 tests pass.

**Step: Commit**

```bash
git add lib/klass_hero/family/application/use_cases/invites/process_invite_claim.ex \
        test/klass_hero/family/application/use_cases/invites/process_invite_claim_test.exs
git commit -m "feat: add ProcessInviteClaim use case for serialized invite processing (#299)"
```

---

### Task 3: Create `ProcessInviteClaimWorker` Oban Worker (TDD)

Thin adapter — deserializes JSON args, calls use case.

**Files:**
- Test: `test/klass_hero/family/adapters/driven/workers/process_invite_claim_worker_test.exs`
- Create: `lib/klass_hero/family/adapters/driven/workers/process_invite_claim_worker.ex`

**Reference files:**
- Existing Oban worker pattern: `lib/klass_hero/enrollment/adapters/driven/workers/send_invite_email_worker.ex`
- Oban test config: `config/test.exs:23` (`testing: :inline`)

#### Cycle 1: Processes invite claim via use case

**RED — Write failing test**

```elixir
defmodule KlassHero.Family.Adapters.Driven.Workers.ProcessInviteClaimWorkerTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Family
  alias KlassHero.Family.Adapters.Driven.Workers.ProcessInviteClaimWorker

  describe "perform/1" do
    test "processes invite claim and creates parent + child" do
      user = user_fixture()

      job =
        ProcessInviteClaimWorker.new(%{
          "invite_id" => Ecto.UUID.generate(),
          "user_id" => user.id,
          "program_id" => Ecto.UUID.generate(),
          "child_first_name" => "Emma",
          "child_last_name" => "Schmidt",
          "child_date_of_birth" => "2016-03-15",
          "school_grade" => 3,
          "school_name" => "Berlin Elementary",
          "medical_conditions" => "Asthma",
          "nut_allergy" => true
        })
        |> Oban.insert!()

      assert :ok = ProcessInviteClaimWorker.perform(job)

      {:ok, parent} = Family.get_parent_by_identity(user.id)
      children = Family.get_children(parent.id)
      assert length(children) == 1
      assert hd(children).first_name == "Emma"
    end
  end
end
```

**Verify RED**

Run: `mix test test/klass_hero/family/adapters/driven/workers/process_invite_claim_worker_test.exs`
Expected: Compilation error — module does not exist

**GREEN — Write minimal implementation**

Create `lib/klass_hero/family/adapters/driven/workers/process_invite_claim_worker.ex`:

```elixir
defmodule KlassHero.Family.Adapters.Driven.Workers.ProcessInviteClaimWorker do
  @moduledoc """
  Oban worker that processes invite claims with per-parent serialization.

  Uses Oban's unique job constraint on `user_id` to ensure only one invite
  claim per parent is processed at a time, preventing duplicate child records
  from concurrent events.
  """

  use Oban.Worker,
    queue: :family,
    max_attempts: 3,
    unique: [keys: [:user_id], period: 60]

  alias KlassHero.Family.Application.UseCases.Invites.ProcessInviteClaim

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case ProcessInviteClaim.execute(deserialize_args(args)) do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        Logger.error("[ProcessInviteClaimWorker] Failed",
          invite_id: args["invite_id"],
          user_id: args["user_id"],
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # Trigger: Oban serializes args as JSON (string keys, ISO date strings)
  # Why: use case expects atom keys and native Elixir types
  # Outcome: converts string keys to atoms, parses date string to Date struct
  defp deserialize_args(args) do
    %{
      invite_id: args["invite_id"],
      user_id: args["user_id"],
      program_id: args["program_id"],
      child_first_name: args["child_first_name"],
      child_last_name: args["child_last_name"],
      child_date_of_birth: parse_date(args["child_date_of_birth"]),
      school_grade: args["school_grade"],
      school_name: args["school_name"],
      medical_conditions: args["medical_conditions"],
      nut_allergy: args["nut_allergy"]
    }
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_date(%Date{} = date), do: date
end
```

**Verify GREEN**

Run: `mix test test/klass_hero/family/adapters/driven/workers/process_invite_claim_worker_test.exs`
Expected: 1 test, 0 failures

#### Cycle 2: Deserializes nil date gracefully

**RED**

Add to the `describe "perform/1"` block:

```elixir
    test "handles nil date_of_birth in args" do
      user = user_fixture()

      job =
        ProcessInviteClaimWorker.new(%{
          "invite_id" => Ecto.UUID.generate(),
          "user_id" => user.id,
          "program_id" => Ecto.UUID.generate(),
          "child_first_name" => "Emma",
          "child_last_name" => "Schmidt",
          "child_date_of_birth" => nil
        })
        |> Oban.insert!()

      # Will fail at domain validation (date_of_birth required), but worker should not crash
      result = ProcessInviteClaimWorker.perform(job)
      assert {:error, _reason} = result
    end
```

**Verify RED** → run test. Should pass or fail depending on domain validation handling. Adjust assertion to match actual behavior.

**Verify GREEN** — both tests pass.

**Step: Commit**

```bash
git add lib/klass_hero/family/adapters/driven/workers/process_invite_claim_worker.ex \
        test/klass_hero/family/adapters/driven/workers/process_invite_claim_worker_test.exs
git commit -m "feat: add ProcessInviteClaimWorker with per-parent Oban uniqueness (#299)"
```

---

### Task 4: Refactor `InviteClaimedHandler` to Enqueue (TDD)

Replace inline domain logic with Oban job enqueue.

**Files:**
- Modify: `test/klass_hero/family/adapters/driven/events/invite_claimed_handler_test.exs`
- Modify: `lib/klass_hero/family/adapters/driven/events/invite_claimed_handler.ex`

**Reference files:**
- Current handler: `lib/klass_hero/family/adapters/driven/events/invite_claimed_handler.ex`
- Current tests: `test/klass_hero/family/adapters/driven/events/invite_claimed_handler_test.exs`

#### Cycle 1: Update tests first, then refactor handler

Since Oban is `testing: :inline` in test config, the end-to-end behavior is the same — the handler enqueues, Oban runs it inline, use case executes. The existing test assertions still hold.

**RED — Update tests to reflect new architecture**

Replace the full test file. The tests verify the same outcomes but via the enqueue → inline-execute path. Key change: test names and module doc reflect the new architecture.

```elixir
defmodule KlassHero.Family.Adapters.Driven.Events.InviteClaimedHandlerTest do
  @moduledoc """
  Tests for InviteClaimedHandler — enqueues Oban job for invite processing.

  Oban is `testing: :inline` in test env, so jobs execute synchronously.
  We verify end-to-end outcomes (parent + child created).
  """

  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Family
  alias KlassHero.Family.Adapters.Driven.Events.InviteClaimedHandler
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  defp build_invite_claimed_event(attrs) do
    invite_id = Map.get(attrs, :invite_id, Ecto.UUID.generate())
    user_id = Map.get(attrs, :user_id, Ecto.UUID.generate())
    program_id = Map.get(attrs, :program_id, Ecto.UUID.generate())
    provider_id = Map.get(attrs, :provider_id, Ecto.UUID.generate())

    payload =
      Map.merge(
        %{
          invite_id: invite_id,
          user_id: user_id,
          program_id: program_id,
          provider_id: provider_id,
          child_first_name: "Emma",
          child_last_name: "Schmidt",
          child_date_of_birth: ~D[2016-03-15],
          guardian_email: "parent@example.com",
          school_grade: 3,
          school_name: "Berlin Elementary",
          medical_conditions: "Asthma",
          nut_allergy: true,
          consent_photo_marketing: false,
          consent_photo_social_media: false
        },
        attrs
      )

    IntegrationEvent.new(
      :invite_claimed,
      :enrollment,
      :invite,
      invite_id,
      payload
    )
  end

  describe "subscribed_events/0" do
    test "subscribes to :invite_claimed" do
      assert :invite_claimed in InviteClaimedHandler.subscribed_events()
    end
  end

  describe "handle_event/1" do
    test "enqueues job that creates parent profile and child" do
      user = user_fixture()
      event = build_invite_claimed_event(%{user_id: user.id})

      assert :ok = InviteClaimedHandler.handle_event(event)

      {:ok, parent} = Family.get_parent_by_identity(user.id)
      children = Family.get_children(parent.id)
      assert length(children) == 1
      child = hd(children)
      assert child.first_name == "Emma"
      assert child.last_name == "Schmidt"
      assert child.date_of_birth == ~D[2016-03-15]
      assert child.school_grade == 3
      assert child.school_name == "Berlin Elementary"
      assert child.support_needs == "Asthma"
      assert child.allergies == "Nut allergy"
    end

    test "maps nut_allergy false to nil allergies" do
      user = user_fixture()
      event = build_invite_claimed_event(%{user_id: user.id, nut_allergy: false})

      assert :ok = InviteClaimedHandler.handle_event(event)

      {:ok, parent} = Family.get_parent_by_identity(user.id)
      child = hd(Family.get_children(parent.id))
      assert is_nil(child.allergies)
    end

    test "handles nil optional fields gracefully" do
      user = user_fixture()

      event =
        build_invite_claimed_event(%{
          user_id: user.id,
          school_grade: nil,
          school_name: nil,
          medical_conditions: nil,
          nut_allergy: false
        })

      assert :ok = InviteClaimedHandler.handle_event(event)

      {:ok, parent} = Family.get_parent_by_identity(user.id)
      child = hd(Family.get_children(parent.id))
      assert is_nil(child.school_grade)
      assert is_nil(child.school_name)
      assert is_nil(child.support_needs)
      assert is_nil(child.allergies)
    end

    test "is idempotent when parent profile already exists" do
      user = user_fixture()
      {:ok, _parent} = Family.create_parent_profile(%{identity_id: user.id})

      event = build_invite_claimed_event(%{user_id: user.id})
      assert :ok = InviteClaimedHandler.handle_event(event)

      {:ok, parent} = Family.get_parent_by_identity(user.id)
      children = Family.get_children(parent.id)
      assert length(children) == 1
    end

    test "ignores unrelated events" do
      event = IntegrationEvent.new(:something_else, :other, :thing, "id", %{})
      assert :ignore = InviteClaimedHandler.handle_event(event)
    end
  end
end
```

**Verify RED**

Run: `mix test test/klass_hero/family/adapters/driven/events/invite_claimed_handler_test.exs`
Expected: All 5 tests still pass (handler hasn't changed yet). This is expected — the tests verify behavior, not implementation. They will continue to pass after the refactor, which is the point.

**GREEN — Refactor the handler to enqueue**

Replace `lib/klass_hero/family/adapters/driven/events/invite_claimed_handler.ex` entirely:

```elixir
defmodule KlassHero.Family.Adapters.Driven.Events.InviteClaimedHandler do
  @moduledoc """
  Integration event handler for `:invite_claimed` events from the Enrollment context.

  Thin adapter that enqueues an Oban job for serialized processing.
  The actual domain logic lives in the `ProcessInviteClaim` use case,
  called by `ProcessInviteClaimWorker`. Oban's unique constraint on
  `user_id` prevents concurrent processing for the same parent.
  """

  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingIntegrationEvents

  alias KlassHero.Family.Adapters.Driven.Workers.ProcessInviteClaimWorker
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  require Logger

  @impl true
  def subscribed_events, do: [:invite_claimed]

  @impl true
  def handle_event(%IntegrationEvent{
        event_type: :invite_claimed,
        entity_id: invite_id,
        payload: payload
      }) do
    args = build_worker_args(invite_id, payload)

    case ProcessInviteClaimWorker.new(args) |> Oban.insert() do
      {:ok, _job} ->
        Logger.info("[InviteClaimedHandler] Enqueued invite processing",
          invite_id: invite_id,
          user_id: payload.user_id
        )

        :ok

      {:error, reason} ->
        Logger.error("[InviteClaimedHandler] Failed to enqueue",
          invite_id: invite_id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  def handle_event(_event), do: :ignore

  defp build_worker_args(invite_id, payload) do
    %{
      invite_id: invite_id,
      user_id: Map.fetch!(payload, :user_id),
      program_id: Map.fetch!(payload, :program_id),
      child_first_name: Map.get(payload, :child_first_name),
      child_last_name: Map.get(payload, :child_last_name),
      child_date_of_birth: serialize_date(Map.get(payload, :child_date_of_birth)),
      school_grade: Map.get(payload, :school_grade),
      school_name: Map.get(payload, :school_name),
      medical_conditions: Map.get(payload, :medical_conditions),
      nut_allergy: Map.get(payload, :nut_allergy, false)
    }
  end

  # Trigger: Oban stores args as JSON
  # Why: %Date{} must be serialized to ISO 8601 for JSON storage
  # Outcome: worker deserializes back to %Date{} in perform/1
  defp serialize_date(%Date{} = date), do: Date.to_iso8601(date)
  defp serialize_date(nil), do: nil
  defp serialize_date(date) when is_binary(date), do: date
end
```

**Verify GREEN**

Run: `mix test test/klass_hero/family/adapters/driven/events/invite_claimed_handler_test.exs`
Expected: All 5 tests pass

**Verify no regressions**

Run: `mix test`
Expected: All tests pass

**Step: Commit**

```bash
git add lib/klass_hero/family/adapters/driven/events/invite_claimed_handler.ex \
        test/klass_hero/family/adapters/driven/events/invite_claimed_handler_test.exs
git commit -m "refactor: InviteClaimedHandler enqueues Oban job instead of inline processing (#299)"
```

---

### Task 5: Precommit Verification

**Step 1: Run precommit**

Run: `mix precommit`
Expected: All checks pass (compile --warnings-as-errors, format, test)

**Step 2: Fix any issues**

If format issues: `mix format`, then commit.
If warnings: fix and commit.

---

### Task 6: Write Remediation Script

One-off script — TDD exception (not production code, run once on live DB).

**Files:**
- Create: `priv/repo/scripts/remediate_duplicate_children.exs`

**Reference:**
- Migration with table schemas: `priv/repo/migrations/20260226000006_create_family_tables.exs`
- Enrollment migration (FK reference): `priv/repo/migrations/20260226000008_create_enrollment_tables.exs`
- Participation migration (FK reference): `priv/repo/migrations/20260226000007_create_participation_tables.exs`
- Fly deploy instructions: memory file MEMORY.md (Seeds section)

**Step 1: Write the script**

The script has a hardcoded `dry_run = true` at the top. To execute, edit to `false` before running.

Algorithm:
1. Find duplicate groups: `(guardian_id, lower(first_name), lower(last_name), date_of_birth)` with count > 1
2. For each group: oldest child = survivor, rest = duplicates
3. Merge non-null fields from duplicates into survivor (COALESCE-style)
4. Re-point references (enrollments, consents, participation_records, behavioral_notes) — skip on unique constraint conflict by deleting the duplicate's conflicting row first
5. Delete duplicate guardian links and child records
6. Each group in its own transaction

```elixir
# Remediation script for issue #299: Duplicate Child on Parent Profile
#
# Identifies duplicate children per guardian (same first_name, last_name, date_of_birth)
# and merges them into a single survivor record.
#
# Usage (via fly ssh console with rpc):
#   DRY RUN (default — logs only, no changes):
#   fly ssh console -a klass-hero-dev -C "/app/bin/klass_hero rpc 'Code.eval_file(\"/app/lib/klass_hero-0.1.0/priv/repo/scripts/remediate_duplicate_children.exs\")'"
#
#   EXECUTE (edit dry_run to false first, redeploy, then run same command)

import Ecto.Query
alias KlassHero.Repo

dry_run = true
IO.puts("[Remediate] Mode: #{if dry_run, do: "DRY RUN", else: "EXECUTE"}\n")

# Step 1: Find duplicate groups
duplicate_groups =
  from(cg in "children_guardians",
    join: c in "children",
    on: c.id == cg.child_id,
    group_by: [
      cg.guardian_id,
      fragment("lower(?)", c.first_name),
      fragment("lower(?)", c.last_name),
      c.date_of_birth
    ],
    having: count(c.id) > 1,
    select: %{
      guardian_id: cg.guardian_id,
      first_name_lower: fragment("lower(?)", c.first_name),
      last_name_lower: fragment("lower(?)", c.last_name),
      date_of_birth: c.date_of_birth,
      count: count(c.id)
    }
  )
  |> Repo.all()

IO.puts("[Remediate] Found #{length(duplicate_groups)} duplicate group(s)")

if duplicate_groups == [] do
  IO.puts("[Remediate] Nothing to do.")
else
  mergeable_fields = [:emergency_contact, :support_needs, :allergies, :school_name, :school_grade]

  for group <- duplicate_groups do
    IO.puts(
      "\n--- #{group.first_name_lower} #{group.last_name_lower} " <>
        "(DOB: #{group.date_of_birth}) — #{group.count} copies ---"
    )

    children_in_group =
      from(c in "children",
        join: cg in "children_guardians",
        on: c.id == cg.child_id,
        where:
          cg.guardian_id == ^group.guardian_id and
            fragment("lower(?)", c.first_name) == ^group.first_name_lower and
            fragment("lower(?)", c.last_name) == ^group.last_name_lower and
            c.date_of_birth == ^group.date_of_birth,
        order_by: [asc: c.inserted_at],
        select: map(c, ^([:id, :inserted_at] ++ mergeable_fields))
      )
      |> Repo.all()

    [survivor | duplicates] = children_in_group
    IO.puts("  Survivor:   #{survivor.id} (#{survivor.inserted_at})")
    for dup <- duplicates, do: IO.puts("  Duplicate:  #{dup.id} (#{dup.inserted_at})")

    unless dry_run do
      Repo.transaction(fn ->
        duplicate_ids = Enum.map(duplicates, & &1.id)

        # 1. Merge non-null fields into survivor
        merged =
          Enum.reduce(duplicates, %{}, fn dup, acc ->
            Enum.reduce(mergeable_fields, acc, fn field, inner ->
              if is_nil(Map.get(survivor, field)) && !is_nil(Map.get(dup, field)) do
                Map.put(inner, field, Map.get(dup, field))
              else
                inner
              end
            end)
          end)

        if merged != %{} do
          from(c in "children", where: c.id == ^survivor.id)
          |> Repo.update_all(set: Enum.to_list(merged))

          IO.puts("  Merged fields: #{inspect(Map.keys(merged))}")
        end

        # 2. Re-point enrollments (delete dup's if survivor already enrolled in same program)
        survivor_programs =
          from(e in "enrollments", where: e.child_id == ^survivor.id, select: e.program_id)
          |> Repo.all()

        if survivor_programs != [] do
          from(e in "enrollments",
            where: e.child_id in ^duplicate_ids and e.program_id in ^survivor_programs
          )
          |> Repo.delete_all()
        end

        {enrolled, _} =
          from(e in "enrollments", where: e.child_id in ^duplicate_ids)
          |> Repo.update_all(set: [child_id: survivor.id])

        IO.puts("  Re-pointed #{enrolled} enrollment(s)")

        # 3. Re-point consents (delete dup's conflicting active consents first)
        for dup_id <- duplicate_ids do
          active_types =
            from(c in "consents",
              where: c.child_id == ^survivor.id and is_nil(c.withdrawn_at),
              select: c.consent_type
            )
            |> Repo.all()

          if active_types != [] do
            from(c in "consents",
              where:
                c.child_id == ^dup_id and
                  c.consent_type in ^active_types and
                  is_nil(c.withdrawn_at)
            )
            |> Repo.delete_all()
          end

          from(c in "consents", where: c.child_id == ^dup_id)
          |> Repo.update_all(set: [child_id: survivor.id])
        end

        IO.puts("  Re-pointed consents")

        # 4. Re-point participation records (delete dup's conflicting sessions)
        for dup_id <- duplicate_ids do
          survivor_sessions =
            from(p in "participation_records",
              where: p.child_id == ^survivor.id,
              select: p.session_id
            )
            |> Repo.all()

          if survivor_sessions != [] do
            from(p in "participation_records",
              where: p.child_id == ^dup_id and p.session_id in ^survivor_sessions
            )
            |> Repo.delete_all()
          end

          from(p in "participation_records", where: p.child_id == ^dup_id)
          |> Repo.update_all(set: [child_id: survivor.id])
        end

        IO.puts("  Re-pointed participation records")

        # 5. Re-point behavioral notes (no unique constraint)
        {notes, _} =
          from(b in "behavioral_notes", where: b.child_id in ^duplicate_ids)
          |> Repo.update_all(set: [child_id: survivor.id])

        IO.puts("  Re-pointed #{notes} behavioral note(s)")

        # 6. Delete duplicate guardian links and child records
        from(cg in "children_guardians", where: cg.child_id in ^duplicate_ids)
        |> Repo.delete_all()

        {deleted, _} =
          from(c in "children", where: c.id in ^duplicate_ids)
          |> Repo.delete_all()

        IO.puts("  Deleted #{deleted} duplicate(s)")
      end)
    end
  end
end
```

**Step 2: Commit**

```bash
git add priv/repo/scripts/remediate_duplicate_children.exs
git commit -m "chore: add remediation script for merging duplicate children (#299)"
```

---

### Task 7: Final Verification & Push

**Step 1: Run full precommit**

Run: `mix precommit`
Expected: All checks pass

**Step 2: Verify commit history**

Run: `git log --oneline -6`
Expected: Clean commits for this branch

**Step 3: Push**

Run: `git push -u origin worktree-bug/299-duplicate-child`
