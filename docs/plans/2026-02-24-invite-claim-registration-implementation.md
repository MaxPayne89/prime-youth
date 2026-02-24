# Invite Claim & Auto-Registration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When a guardian clicks an invite link, the system auto-registers them and creates their child + enrollment via an event-driven choreography saga.

**Architecture:** Event-driven saga using existing DomainEventBus (intra-context) + IntegrationEvent/PubSub (cross-context). Three async steps: web layer creates account → Family creates child → Enrollment creates enrollment. Each step triggers the next via events.

**Tech Stack:** Elixir, Phoenix controllers, DomainEventBus, IntegrationEvent + PubSub, Ecto, Oban (not needed — events are synchronous via PubSub).

**Design Doc:** `docs/plans/2026-02-24-invite-claim-registration-design.md`

---

## Event Flow Reference

```
Web Layer: validate token → create user → publish :invite_claimed (domain event on Enrollment bus)
  ↓ (PromoteIntegrationEvents → PubSub topic: integration:enrollment:invite_claimed)
  ↓
Enrollment handler (domain bus): invite_sent → registered
Family handler (integration subscriber): create parent profile + child
  ↓ (publish :invite_family_ready domain event on Family bus)
  ↓ (PromoteIntegrationEvents → PubSub topic: integration:family:invite_family_ready)
  ↓
Enrollment handler (integration subscriber): create enrollment, registered → enrolled
```

## Important Context

- `Accounts.register_user/1` already dispatches `user_registered` which triggers `FamilyEventHandler` to create a parent profile if `intended_roles` includes `"parent"`. This is async via PubSub so there's a race condition — the Family invite handler must check/create the parent profile itself (idempotent).
- `registration_changeset` casts `[:name, :email, :intended_roles]` — no password. Auth is magic-link based.
- `deliver_login_instructions/2` generates a token AND sends an email. We need just the token for the redirect, so we add a thin `generate_magic_link_token/1` to Accounts.
- Existing patterns to follow:
  - Domain event factory: `lib/klass_hero/enrollment/domain/events/enrollment_events.ex`
  - Integration event factory: `lib/klass_hero/accounts/domain/events/accounts_integration_events.ex`
  - PromoteIntegrationEvents: `lib/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events.ex`
  - Integration handler: `lib/klass_hero/family/adapters/driven/events/family_event_handler.ex`
  - EventSubscriber wiring: `lib/klass_hero/application.ex` lines 174-221
  - DomainEventBus wiring: `lib/klass_hero/application.ex` lines 61-112

---

## Task 1: Add `get_by_token/1` to Invite Repository

The invite claim flow starts by looking up an invite by its token.

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex`
- Modify: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex`
- Test: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs` (create if needed)

**Step 1: Write the failing test**

```elixir
# test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Repo

  describe "get_by_token/1" do
    test "returns invite when token matches" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)

      {:ok, 1} =
        BulkEnrollmentInviteRepository.create_batch([
          %{
            program_id: program.id,
            provider_id: provider.id,
            child_first_name: "Emma",
            child_last_name: "Schmidt",
            child_date_of_birth: ~D[2016-03-15],
            guardian_email: "parent@example.com"
          }
        ])

      invite = Repo.one!(BulkEnrollmentInviteSchema)
      token = "test-token-#{System.unique_integer()}"
      invite |> Ecto.Changeset.change(%{invite_token: token}) |> Repo.update!()

      result = BulkEnrollmentInviteRepository.get_by_token(token)
      assert result != nil
      assert result.id == invite.id
      assert result.invite_token == token
    end

    test "returns nil when token not found" do
      assert BulkEnrollmentInviteRepository.get_by_token("nonexistent") == nil
    end

    test "returns nil for nil token" do
      assert BulkEnrollmentInviteRepository.get_by_token(nil) == nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs -v`
Expected: FAIL — `get_by_token/1` undefined

**Step 3: Add callback to port**

In `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex`, add:

```elixir
@doc """
Retrieves a single invite by its invite token.

Returns the invite domain struct or nil if not found.
"""
@callback get_by_token(binary() | nil) :: struct() | nil
```

**Step 4: Implement in repository**

In `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex`, add:

```elixir
@impl true
def get_by_token(nil), do: nil

def get_by_token(token) when is_binary(token) do
  BulkEnrollmentInviteSchema
  |> where([i], i.invite_token == ^token)
  |> Repo.one()
  |> case do
    nil -> nil
    schema -> Mapper.to_domain(schema)
  end
end
```

**Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs -v`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex \
  lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex \
  test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs
git commit -m "feat(enrollment): add get_by_token to invite repository (#176)"
```

---

## Task 2: Add `generate_magic_link_token/1` to Accounts

The invite claim flow needs to generate a magic link token for the redirect WITHOUT sending an email.

**Files:**
- Modify: `lib/klass_hero/accounts.ex`
- Test: `test/klass_hero/accounts_test.exs` (add to existing)

**Step 1: Write the failing test**

Add to the existing accounts test file (or create a focused test):

```elixir
# test/klass_hero/accounts/generate_magic_link_token_test.exs
defmodule KlassHero.Accounts.GenerateMagicLinkTokenTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Accounts

  import KlassHero.AccountsFixtures

  describe "generate_magic_link_token/1" do
    test "returns an encoded token string" do
      user = user_fixture()
      token = Accounts.generate_magic_link_token(user)
      assert is_binary(token)
      assert byte_size(token) > 0
    end

    test "generated token can be verified" do
      user = user_fixture()
      token = Accounts.generate_magic_link_token(user)

      found_user = Accounts.get_user_by_magic_link_token(token)
      assert found_user.id == user.id
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/accounts/generate_magic_link_token_test.exs -v`
Expected: FAIL — `generate_magic_link_token/1` undefined

**Step 3: Implement**

In `lib/klass_hero/accounts.ex`, add after `deliver_login_instructions/2`:

```elixir
@doc """
Generates a magic link login token for a user without sending an email.

Used by the invite claim flow where the redirect URL is built directly.
Returns the URL-safe encoded token string.
"""
def generate_magic_link_token(%User{} = user) do
  {encoded_token, user_token} = UserToken.build_email_token(user, "login")
  Repo.insert!(user_token)
  encoded_token
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/accounts/generate_magic_link_token_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/klass_hero/accounts.ex \
  test/klass_hero/accounts/generate_magic_link_token_test.exs
git commit -m "feat(accounts): add generate_magic_link_token for invite flow (#176)"
```

---

## Task 3: Add `:invite_claimed` Event Factories

Domain event (for Enrollment bus) + integration event (for PubSub cross-context).

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/events/enrollment_events.ex`
- Create: `lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex`
- Test: `test/klass_hero/enrollment/domain/events/enrollment_events_test.exs`
- Test: `test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs`

**Step 1: Write the failing tests**

```elixir
# test/klass_hero/enrollment/domain/events/enrollment_events_invite_claimed_test.exs
defmodule KlassHero.Enrollment.Domain.Events.EnrollmentEventsInviteClaimedTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "invite_claimed/3" do
    test "creates a domain event with correct structure" do
      invite_id = Ecto.UUID.generate()

      payload = %{
        invite_id: invite_id,
        user_id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        provider_id: Ecto.UUID.generate(),
        is_new_user: true,
        child: %{first_name: "Emma", last_name: "Schmidt"},
        guardian: %{email: "parent@example.com"},
        consents: %{photo_marketing: false}
      }

      event = EnrollmentEvents.invite_claimed(invite_id, payload)

      assert %DomainEvent{} = event
      assert event.event_type == :invite_claimed
      assert event.aggregate_id == invite_id
      assert event.payload.invite_id == invite_id
    end

    test "raises on empty invite_id" do
      assert_raise ArgumentError, fn ->
        EnrollmentEvents.invite_claimed("", %{})
      end
    end
  end
end
```

```elixir
# test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs
defmodule KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEventsTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEvents
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  describe "invite_claimed/3" do
    test "creates an integration event with correct structure" do
      invite_id = Ecto.UUID.generate()
      payload = %{invite_id: invite_id, user_id: Ecto.UUID.generate()}

      event = EnrollmentIntegrationEvents.invite_claimed(invite_id, payload)

      assert %IntegrationEvent{} = event
      assert event.event_type == :invite_claimed
      assert event.source_context == :enrollment
      assert event.entity_type == :invite
      assert event.entity_id == invite_id
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_events_invite_claimed_test.exs test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs -v`
Expected: FAIL

**Step 3: Add `invite_claimed/3` to EnrollmentEvents**

In `lib/klass_hero/enrollment/domain/events/enrollment_events.ex`, add:

```elixir
@doc """
Creates an `:invite_claimed` event when a guardian clicks an invite link.

## Parameters

- `invite_id` — the invite being claimed
- `payload` — invite data including user_id, child info, guardian info
- `opts` — forwarded to `DomainEvent.new/5`
"""
def invite_claimed(invite_id, payload \\ %{}, opts \\ [])

def invite_claimed(invite_id, payload, opts)
    when is_binary(invite_id) and byte_size(invite_id) > 0 do
  base_payload = %{invite_id: invite_id}

  DomainEvent.new(
    :invite_claimed,
    invite_id,
    @aggregate_type,
    Map.merge(payload, base_payload),
    opts
  )
end

def invite_claimed(invite_id, _payload, _opts) do
  raise ArgumentError,
        "invite_claimed/3 requires a non-empty invite_id string, got: #{inspect(invite_id)}"
end
```

**Step 4: Create EnrollmentIntegrationEvents**

Follow the pattern from `AccountsIntegrationEvents`:

```elixir
# lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex
defmodule KlassHero.Enrollment.Domain.Events.EnrollmentIntegrationEvents do
  @moduledoc """
  Factory module for creating Enrollment context integration events.

  Integration events are the public contract between bounded contexts.
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @source_context :enrollment
  @entity_type :invite

  @doc """
  Creates an `invite_claimed` integration event.

  Published when a guardian clicks an invite link and their account is resolved.
  Family context subscribes to create child records.
  """
  def invite_claimed(invite_id, payload \\ %{}, opts \\ [])

  def invite_claimed(invite_id, payload, opts)
      when is_binary(invite_id) and byte_size(invite_id) > 0 do
    base_payload = %{invite_id: invite_id}

    IntegrationEvent.new(
      :invite_claimed,
      @source_context,
      @entity_type,
      invite_id,
      Map.merge(payload, base_payload),
      opts
    )
  end

  def invite_claimed(invite_id, _payload, _opts) do
    raise ArgumentError,
          "invite_claimed/3 requires a non-empty invite_id string, got: #{inspect(invite_id)}"
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/enrollment/domain/events/enrollment_events_invite_claimed_test.exs test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs -v`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/klass_hero/enrollment/domain/events/enrollment_events.ex \
  lib/klass_hero/enrollment/domain/events/enrollment_integration_events.ex \
  test/klass_hero/enrollment/domain/events/enrollment_events_invite_claimed_test.exs \
  test/klass_hero/enrollment/domain/events/enrollment_integration_events_test.exs
git commit -m "feat(enrollment): add invite_claimed domain + integration events (#176)"
```

---

## Task 4: Add `:invite_family_ready` Event Factories

Family context publishes this after creating parent + child from an invite.

**Files:**
- Modify: `lib/klass_hero/family/domain/events/family_events.ex`
- Create: `lib/klass_hero/family/domain/events/family_integration_events.ex` (if not exists, check first)
- Test: `test/klass_hero/family/domain/events/family_events_invite_family_ready_test.exs`
- Test: `test/klass_hero/family/domain/events/family_integration_events_test.exs`

**Pattern:** Same as Task 3, but:
- Domain event: `FamilyEvents.invite_family_ready(invite_id, payload)` on Family bus
- Integration event: source_context `:family`, entity_type `:invite`, topic `integration:family:invite_family_ready`
- Payload: `%{invite_id, user_id, child_id, parent_id, program_id}`

Follow the exact same TDD pattern as Task 3. Check if `FamilyIntegrationEvents` already exists first — if not, create it following the `AccountsIntegrationEvents` pattern.

**Commit message:** `feat(family): add invite_family_ready domain + integration events (#176)`

---

## Task 5: Enrollment Domain Handler — `:invite_claimed` Status Transition

Transitions invite from `invite_sent → registered` when the account is claimed.

**Files:**
- Create: `lib/klass_hero/enrollment/adapters/driven/events/event_handlers/mark_invite_registered.ex`
- Test: `test/klass_hero/enrollment/adapters/driven/events/event_handlers/mark_invite_registered_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.MarkInviteRegisteredTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.MarkInviteRegistered
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Repo

  defp create_invite_sent(_context) do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)

    {:ok, 1} =
      BulkEnrollmentInviteRepository.create_batch([
        %{
          program_id: program.id,
          provider_id: provider.id,
          child_first_name: "Emma",
          child_last_name: "Schmidt",
          child_date_of_birth: ~D[2016-03-15],
          guardian_email: "parent@example.com"
        }
      ])

    invite = Repo.one!(BulkEnrollmentInviteSchema)

    # Transition to invite_sent (requires token first)
    invite
    |> Ecto.Changeset.change(%{invite_token: "test-token", status: "invite_sent"})
    |> Repo.update!()

    %{invite: Repo.one!(BulkEnrollmentInviteSchema), provider: provider, program: program}
  end

  describe "handle/1" do
    setup :create_invite_sent

    test "transitions invite from invite_sent to registered", %{invite: invite} do
      event =
        EnrollmentEvents.invite_claimed(invite.id, %{
          invite_id: invite.id,
          user_id: Ecto.UUID.generate()
        })

      assert :ok = MarkInviteRegistered.handle(event)

      updated = Repo.get!(BulkEnrollmentInviteSchema, invite.id)
      assert updated.status == "registered"
      assert updated.registered_at != nil
    end

    test "is idempotent when already registered", %{invite: invite} do
      invite |> Ecto.Changeset.change(%{status: "registered"}) |> Repo.update!()

      event =
        EnrollmentEvents.invite_claimed(invite.id, %{
          invite_id: invite.id,
          user_id: Ecto.UUID.generate()
        })

      assert :ok = MarkInviteRegistered.handle(event)
    end
  end
end
```

**Step 2: Implement**

```elixir
# lib/klass_hero/enrollment/adapters/driven/events/event_handlers/mark_invite_registered.ex
defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.MarkInviteRegistered do
  @moduledoc """
  Domain event handler that transitions an invite from invite_sent to registered
  when the guardian claims the invite link.

  Triggered by `:invite_claimed` on the Enrollment DomainEventBus.
  Idempotent: skips if invite is already registered or beyond.
  """

  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @invite_repository Application.compile_env!(
                       :klass_hero,
                       [:enrollment, :for_storing_bulk_enrollment_invites]
                     )

  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{event_type: :invite_claimed} = event) do
    %{invite_id: invite_id} = event.payload

    case @invite_repository.get_by_id(invite_id) do
      nil ->
        Logger.warning("[MarkInviteRegistered] Invite not found", invite_id: invite_id)
        :ok

      invite ->
        maybe_transition(invite)
    end
  end

  # Trigger: invite is already at or past the registered state
  # Why: idempotent — event may be dispatched more than once
  # Outcome: skip transition, return :ok
  defp maybe_transition(%{status: status}) when status in ["registered", "enrolled"] do
    :ok
  end

  defp maybe_transition(invite) do
    case @invite_repository.transition_status(invite, %{
           status: "registered",
           registered_at: DateTime.utc_now() |> DateTime.truncate(:second)
         }) do
      {:ok, _} ->
        Logger.info("[MarkInviteRegistered] Invite transitioned to registered",
          invite_id: invite.id
        )

        :ok

      {:error, reason} ->
        Logger.error("[MarkInviteRegistered] Failed to transition invite",
          invite_id: invite.id,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end
end
```

**Step 3: Run tests, verify pass, commit**

```bash
git commit -m "feat(enrollment): add MarkInviteRegistered domain event handler (#176)"
```

---

## Task 6: Enrollment PromoteIntegrationEvents — Add `:invite_claimed`

**Files:**
- Modify: `lib/klass_hero/enrollment/adapters/driven/events/event_handlers/promote_integration_events.ex`
- Test: modify existing test or create new

**Implementation:** Add a `handle/1` clause for `:invite_claimed`:

```elixir
def handle(%DomainEvent{event_type: :invite_claimed} = event) do
  event.payload.invite_id
  |> EnrollmentIntegrationEvents.invite_claimed(event.payload)
  |> IntegrationEventPublishing.publish()
end
```

Check if `PromoteIntegrationEvents` already exists for Enrollment — if not, create it following the Accounts pattern. Wire it on the Enrollment DomainEventBus at priority 10 (same as other PromoteIntegrationEvents handlers).

**Commit message:** `feat(enrollment): promote invite_claimed to integration event (#176)`

---

## Task 7: Family Integration Handler — `:invite_claimed`

Creates parent profile (if missing) and child from invite data.

**Files:**
- Create: `lib/klass_hero/family/adapters/driven/events/invite_claimed_handler.ex`
- Test: `test/klass_hero/family/adapters/driven/events/invite_claimed_handler_test.exs`

**Key behavior:**
1. Receive `:invite_claimed` integration event
2. Check if parent profile exists for `user_id` → create if not (idempotent)
3. Create child from invite data, linked to parent
4. Publish `:invite_family_ready` domain event on Family bus with `{invite_id, user_id, child_id, parent_id, program_id}`
5. On failure: log rich error context (invite_id, user_id, step, reason)

**Implementation pattern:** Follow `FamilyEventHandler` but implement `ForHandlingIntegrationEvents` behaviour. Use `Family.create_parent_profile/1` and `Family.create_child/1` from the public API.

**Child creation attrs mapping from invite payload:**
```elixir
%{
  parent_id: parent.id,
  first_name: child.first_name,
  last_name: child.last_name,
  date_of_birth: child.date_of_birth,
  school_grade: child.school_grade,
  school_name: child.school_name
  # medical_conditions and nut_allergy need to be mapped to the Child schema fields
  # Check Child domain model for field names: allergies, support_needs
}
```

**Important:** Check the Child domain model fields carefully. The invite has `medical_conditions` and `nut_allergy` — map these to the correct Child fields (likely `allergies` and `support_needs` or similar).

**Idempotency for child:** If a child with the same (parent, first_name, last_name, date_of_birth) already exists, use the existing child. The child repository may not have a lookup for this — add one if needed, or handle the unique constraint error gracefully.

**Commit message:** `feat(family): add InviteClaimedHandler for child creation from invite (#176)`

---

## Task 8: Family PromoteIntegrationEvents — Add `:invite_family_ready`

**Files:**
- Modify: `lib/klass_hero/family/adapters/driven/events/event_handlers/promote_integration_events.ex`

**Implementation:** Add a handler clause for `:invite_family_ready`:

```elixir
def handle(%DomainEvent{event_type: :invite_family_ready} = event) do
  event.payload.invite_id
  |> FamilyIntegrationEvents.invite_family_ready(event.payload)
  |> IntegrationEventPublishing.publish()
end
```

Register it on the Family DomainEventBus in `application.ex`.

**Commit message:** `feat(family): promote invite_family_ready to integration event (#176)`

---

## Task 9: Enrollment Integration Handler — `:invite_family_ready`

Creates the enrollment and transitions invite to `enrolled`.

**Files:**
- Create: `lib/klass_hero/enrollment/adapters/driven/events/invite_family_ready_handler.ex`
- Test: `test/klass_hero/enrollment/adapters/driven/events/invite_family_ready_handler_test.exs`

**Key behavior:**
1. Receive `:invite_family_ready` integration event with `{invite_id, user_id, child_id, parent_id, program_id}`
2. Fetch invite, validate status is `registered`
3. Create enrollment via `Enrollment.create_enrollment/1` with:
   ```elixir
   %{
     program_id: payload.program_id,
     child_id: payload.child_id,
     parent_id: payload.parent_id,
     status: "confirmed",
     payment_method: "transfer"  # Bulk invites have no payment
   }
   ```
4. Transition invite: `registered → enrolled`, set `enrolled_at`, set `enrollment_id`
5. On failure: transition invite → `failed` with error details

**Idempotency:** If enrollment already exists for (program_id, child_id), skip creation. Transition invite to `enrolled` if not already.

**Implement as:** `ForHandlingIntegrationEvents` behaviour. Wire as EventSubscriber in `application.ex`.

**Commit message:** `feat(enrollment): add InviteFamilyReadyHandler for enrollment creation (#176)`

---

## Task 10: ClaimInvite Use Case

Orchestrates the invite claim: validate token, resolve/create user, publish event.

**Files:**
- Create: `lib/klass_hero/enrollment/application/use_cases/claim_invite.ex`
- Test: `test/klass_hero/enrollment/application/use_cases/claim_invite_test.exs`

**Key behavior:**
```
execute(token) →
  1. get_by_token(token) → nil? → {:error, :not_found}
  2. invite.status != "invite_sent"? → {:error, :already_claimed}
  3. Accounts.get_user_by_email(invite.guardian_email)
     → exists? → {:ok, :existing_user, user, invite}
     → nil? →
       a. Accounts.register_user(%{
            name: guardian_name(invite),
            email: invite.guardian_email,
            intended_roles: [:parent]
          })
       b. → {:ok, :new_user, user, invite}
  4. Publish :invite_claimed domain event on Enrollment bus
  5. Return result
```

**Test cases:**
- Token not found → `{:error, :not_found}`
- Invite already claimed (status not invite_sent) → `{:error, :already_claimed}`
- New user → creates account, publishes event, returns `{:ok, :new_user, user, invite}`
- Existing user → skips creation, publishes event, returns `{:ok, :existing_user, user, invite}`

**Commit message:** `feat(enrollment): add ClaimInvite use case (#176)`

---

## Task 11: Enrollment Facade — Public API

**Files:**
- Modify: `lib/klass_hero/enrollment.ex`

**Add:**

```elixir
@doc """
Claims a bulk enrollment invite by token.

Validates the token, resolves or creates the user account, and publishes
the :invite_claimed event to trigger the async saga (child creation → enrollment).

Returns:
- `{:ok, :new_user, user, invite}` — new account created
- `{:ok, :existing_user, user, invite}` — existing account found
- `{:error, :not_found}` — invalid or expired token
- `{:error, :already_claimed}` — invite already processed
"""
def claim_invite(token) when is_binary(token) do
  ClaimInvite.execute(token)
end
```

**Commit message:** `feat(enrollment): add claim_invite to public API (#176)`

---

## Task 12: InviteClaimController + Route

**Files:**
- Create: `lib/klass_hero_web/controllers/invite_claim_controller.ex`
- Modify: `lib/klass_hero_web/router.ex`
- Test: `test/klass_hero_web/controllers/invite_claim_controller_test.exs`

**Controller:**

```elixir
defmodule KlassHeroWeb.InviteClaimController do
  use KlassHeroWeb, :controller

  alias KlassHero.Accounts
  alias KlassHero.Enrollment

  def show(conn, %{"token" => token}) do
    case Enrollment.claim_invite(token) do
      {:ok, :new_user, user, _invite} ->
        magic_token = Accounts.generate_magic_link_token(user)

        conn
        |> put_flash(:info, "Your account has been created! Set up your password in settings.")
        |> redirect(to: ~p"/users/log-in/#{magic_token}")

      {:ok, :existing_user, _user, _invite} ->
        conn
        |> put_flash(:info, "You already have an account. Log in to see your new enrollment.")
        |> redirect(to: ~p"/users/log-in")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "This invite link is invalid or has expired.")
        |> redirect(to: ~p"/")

      {:error, :already_claimed} ->
        conn
        |> put_flash(:info, "This invite has already been used.")
        |> redirect(to: ~p"/users/log-in")
    end
  end
end
```

**Route** — add in the public browser scope (no auth required):

```elixir
# In the scope "/", KlassHeroWeb block with pipe_through [:browser]
get "/invites/:token", InviteClaimController, :show
```

Place this in the unauthenticated section of the router (the `scope "/", KlassHeroWeb do pipe_through [:browser]` block near the bottom, alongside the auth routes).

**Test cases:**
- Valid token, new user → redirects to `/users/log-in/:token` with flash
- Valid token, existing user → redirects to `/users/log-in` with flash
- Invalid token → redirects to `/` with error flash
- Already claimed → redirects to `/users/log-in` with info flash

**Commit message:** `feat(web): add InviteClaimController and /invites/:token route (#176)`

---

## Task 13: Update Email Template

**Files:**
- Modify: `lib/klass_hero/enrollment/adapters/driven/notifications/invite_email_notifier.ex`

**Change:** Add a line to the email body (both HTML and text versions):

> "After clicking the link below, your account will be created automatically. You can set a password in your account settings at any time."

Place this before the "Complete Registration" button.

**Commit message:** `feat(enrollment): add password note to invite email template (#176)`

---

## Task 14: Supervision Tree Wiring

**Files:**
- Modify: `lib/klass_hero/application.ex`

**Changes needed:**

### 1. Register domain handlers on Enrollment bus

Add to the Enrollment DomainEventBus handlers list:

```elixir
{:invite_claimed,
 {KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.MarkInviteRegistered,
  :handle}},
{:invite_claimed,
 {KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
  :handle}, priority: 10}
```

### 2. Register domain handler on Family bus

Add `:invite_family_ready` to the Family DomainEventBus handlers:

```elixir
{:invite_family_ready,
 {KlassHero.Family.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
  :handle}, priority: 10}
```

### 3. Add integration event subscribers

Add to `start_projections/0`:

```elixir
# Family listens for invite_claimed from Enrollment
Supervisor.child_spec(
  {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
   handler: KlassHero.Family.Adapters.Driven.Events.InviteClaimedHandler,
   topics: ["integration:enrollment:invite_claimed"],
   message_tag: :integration_event,
   event_label: "Integration event"},
  id: :family_enrollment_invite_subscriber
),
# Enrollment listens for invite_family_ready from Family
Supervisor.child_spec(
  {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
   handler: KlassHero.Enrollment.Adapters.Driven.Events.InviteFamilyReadyHandler,
   topics: ["integration:family:invite_family_ready"],
   message_tag: :integration_event,
   event_label: "Integration event"},
  id: :enrollment_family_invite_subscriber
)
```

**Commit message:** `feat(app): wire invite claim saga handlers in supervision tree (#176)`

---

## Task 15: End-to-End Integration Test

**Files:**
- Create: `test/klass_hero_web/controllers/invite_claim_controller_test.exs` (may already exist from Task 12)

**Test the full saga:** Create an invite with status `invite_sent` + token → GET `/invites/:token` → verify redirect + user created + (wait briefly) child created + enrollment created.

Note: Integration event handlers run asynchronously via PubSub. In tests, you may need to either:
1. Test the controller and handlers separately (unit tests)
2. Use `Process.sleep/1` or poll for the expected state (integration test)

Prefer option 1 for reliability. The unit tests in Tasks 5, 7, 9 cover handler logic. The controller test in Task 12 covers the web layer.

**Commit message:** `test: add end-to-end invite claim integration test (#176)`

---

## Task 16: Update Context Documentation

**Files:**
- Modify: `docs/contexts/enrollment/README.md`
- Modify: `docs/contexts/enrollment/features/invite-email-pipeline.md`
- Modify: `docs/contexts/enrollment/features/import-enrollment-csv.md`

**Changes:**
- Mark "Handling the registration link when a guardian clicks it" as resolved in invite-email-pipeline.md
- Update the enrollment README to document the new `claim_invite/1` public API
- Update the "What It Does NOT Do" section in import-enrollment-csv.md to reflect that invite claiming is now implemented
- Resolve the open question: "What happens after a parent registers from a bulk invite?"

**Commit message:** `docs: update enrollment context docs for invite claim flow (#176)`

---

## Execution Order Summary

| Task | Dependency | Context |
|------|-----------|---------|
| 1. get_by_token repository | None | Enrollment |
| 2. generate_magic_link_token | None | Accounts |
| 3. invite_claimed events | None | Enrollment |
| 4. invite_family_ready events | None | Family |
| 5. MarkInviteRegistered handler | 1, 3 | Enrollment |
| 6. Enrollment PromoteIntegrationEvents | 3 | Enrollment |
| 7. Family InviteClaimedHandler | 4 | Family |
| 8. Family PromoteIntegrationEvents | 4 | Family |
| 9. Enrollment InviteFamilyReadyHandler | 1 | Enrollment |
| 10. ClaimInvite use case | 1, 3 | Enrollment |
| 11. Enrollment facade | 10 | Enrollment |
| 12. Controller + route | 2, 11 | Web |
| 13. Email template | None | Enrollment |
| 14. Supervision tree | 5, 6, 7, 8, 9 | App |
| 15. Integration test | All above | Test |
| 16. Documentation | All above | Docs |

Tasks 1-4 are independent and can be parallelized.
Tasks 5-9 can be partially parallelized (5+6 together, 7+8 together, 9 separate).
Tasks 10-14 are mostly sequential.
