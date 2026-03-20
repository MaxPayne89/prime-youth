# Provider Registration Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix provider registration so the selected subscription tier is persisted and a `user_confirmed` compensation event ensures profile creation before first login.

**Architecture:** Saga choreography with eventual consistency. Persist `provider_subscription_tier` as a real DB column, enrich and promote `user_confirmed` as a critical integration event, and have Provider/Family handlers subscribe to it as an idempotent compensation path.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, Ecto, PostgreSQL, PubSub, DomainEventBus

**Spec:** `docs/superpowers/specs/2026-03-20-provider-registration-fix-design.md`

**Required Skills:**
- @idiomatic-elixir — use for all Elixir code in this plan
- @superpowers:test-driven-development — every task follows red-green-commit TDD

---

### Task 1: Persist `provider_subscription_tier`

**Files:**
- Create: `priv/repo/migrations/YYYYMMDDHHMMSS_add_provider_subscription_tier_to_users.exs`
- Modify: `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex:36`

- [ ] **Step 1: Generate migration**

Run: `mix ecto.gen.migration add_provider_subscription_tier_to_users`

- [ ] **Step 2: Write migration**

In the generated migration file:

```elixir
def change do
  alter table(:users) do
    add :provider_subscription_tier, :string
  end
end
```

- [ ] **Step 3: Remove `virtual: true` from schema**

In `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex`, change line 36 from:

```elixir
field :provider_subscription_tier, :string, virtual: true
```

to:

```elixir
field :provider_subscription_tier, :string
```

- [ ] **Step 4: Run migration and verify**

Run: `mix ecto.migrate`

Expected: Migration succeeds, no warnings.

- [ ] **Step 5: Run existing tests to verify no regressions**

Run: `mix test test/klass_hero/accounts/ --max-failures 5`

Expected: All tests pass. The `registration_changeset` already casts and validates this field — removing `virtual: true` just makes Ecto persist it.

- [ ] **Step 6: Commit**

```bash
git add priv/repo/migrations/*provider_subscription_tier* lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex
git commit -m "fix: persist provider_subscription_tier as real DB column

Removes virtual: true so the selected tier survives Repo.insert and
flows into the user_registered event payload correctly.

Refs #484"
```

---

### Task 2: Enrich `user_confirmed` domain event payload

**Files:**
- Test: `test/klass_hero/accounts/domain/events/user_events_test.exs`
- Modify: `lib/klass_hero/accounts/domain/events/user_events.ex:135-150`

- [ ] **Step 1: Write failing test for enriched payload**

Add to `test/klass_hero/accounts/domain/events/user_events_test.exs`, inside the existing `describe "user_confirmed/3 validation"` block, after the last test:

```elixir
test "includes name, intended_roles, and provider_subscription_tier in payload" do
  confirmed_at = ~U[2024-01-01 12:00:00Z]

  user = %{
    id: 1,
    email: "test@example.com",
    name: "Test Provider",
    confirmed_at: confirmed_at,
    intended_roles: [:provider],
    provider_subscription_tier: "professional"
  }

  event = UserEvents.user_confirmed(user)

  assert event.payload.name == "Test Provider"
  assert event.payload.intended_roles == ["provider"]
  assert event.payload.provider_subscription_tier == "professional"
end

test "handles nil intended_roles and provider_subscription_tier gracefully" do
  confirmed_at = ~U[2024-01-01 12:00:00Z]
  user = %{id: 1, email: "test@example.com", confirmed_at: confirmed_at}

  event = UserEvents.user_confirmed(user)

  assert event.payload.intended_roles == []
  assert event.payload.provider_subscription_tier == nil
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/accounts/domain/events/user_events_test.exs --max-failures 2`

Expected: FAIL — `payload.name`, `payload.intended_roles`, `payload.provider_subscription_tier` are not set.

- [ ] **Step 3: Enrich the `user_confirmed` base_payload**

In `lib/klass_hero/accounts/domain/events/user_events.ex`, replace the `user_confirmed` function body (lines 135-150):

```elixir
def user_confirmed(%{id: _, email: _, confirmed_at: _} = user, payload \\ %{}, opts \\ []) do
  validate_user_for_confirmation!(user)

  base_payload = %{
    email: user.email,
    name: Map.get(user, :name),
    confirmed_at: user.confirmed_at,
    intended_roles: Enum.map(Map.get(user, :intended_roles) || [], &Atom.to_string/1),
    provider_subscription_tier: Map.get(user, :provider_subscription_tier)
  }

  DomainEvent.new(
    :user_confirmed,
    user.id,
    @aggregate_type,
    Map.merge(base_payload, payload),
    opts
  )
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/accounts/domain/events/user_events_test.exs`

Expected: All tests pass (new + existing).

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/accounts/domain/events/user_events_test.exs lib/klass_hero/accounts/domain/events/user_events.ex
git commit -m "feat: enrich user_confirmed event with name, roles, and tier

Downstream handlers need these fields to create profiles on the
compensation path without cross-context queries."
```

---

### Task 3: Add `user_confirmed` integration event factory

**Files:**
- Test: `test/klass_hero/accounts/domain/events/accounts_integration_events_test.exs`
- Modify: `lib/klass_hero/accounts/domain/events/accounts_integration_events.ex`

- [ ] **Step 1: Write failing tests**

Add a new `describe "user_confirmed/3"` block to `test/klass_hero/accounts/domain/events/accounts_integration_events_test.exs`, after the `user_anonymized` describe block:

```elixir
describe "user_confirmed/3" do
  test "creates event with correct type, source_context, and entity_type" do
    user_id = Ecto.UUID.generate()

    event = AccountsIntegrationEvents.user_confirmed(user_id)

    assert %IntegrationEvent{} = event
    assert event.event_type == :user_confirmed
    assert event.source_context == :accounts
    assert event.entity_type == :user
    assert event.entity_id == user_id
  end

  test "includes user_id in payload alongside caller data" do
    user_id = Ecto.UUID.generate()

    event =
      AccountsIntegrationEvents.user_confirmed(user_id, %{
        intended_roles: ["provider"],
        provider_subscription_tier: "professional"
      })

    assert event.payload.user_id == user_id
    assert event.payload.intended_roles == ["provider"]
    assert event.payload.provider_subscription_tier == "professional"
  end

  test "base_payload user_id wins over caller-supplied user_id" do
    real_id = Ecto.UUID.generate()
    conflicting_payload = %{user_id: "should-be-overridden", extra: "data"}

    event = AccountsIntegrationEvents.user_confirmed(real_id, conflicting_payload)

    assert event.payload.user_id == real_id
    assert event.payload.extra == "data"
  end

  test "marks event as critical by default" do
    user_id = Ecto.UUID.generate()

    event = AccountsIntegrationEvents.user_confirmed(user_id)

    assert IntegrationEvent.critical?(event)
  end

  test "raises for nil user_id" do
    assert_raise ArgumentError,
                 ~r/requires a non-empty user_id string/,
                 fn -> AccountsIntegrationEvents.user_confirmed(nil) end
  end

  test "raises for empty string user_id" do
    assert_raise ArgumentError,
                 ~r/requires a non-empty user_id string/,
                 fn -> AccountsIntegrationEvents.user_confirmed("") end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/accounts/domain/events/accounts_integration_events_test.exs --max-failures 1`

Expected: FAIL — `AccountsIntegrationEvents.user_confirmed/3` is undefined.

- [ ] **Step 3: Implement `user_confirmed/3`**

In `lib/klass_hero/accounts/domain/events/accounts_integration_events.ex`, add after the `user_registered` error clause (after line 81) and before the `user_anonymized` `@doc`:

```elixir
@doc """
Creates a `user_confirmed` integration event.

Marked `:critical` by default — downstream contexts use this as a compensation
path to ensure profiles exist before first login.

## Parameters

- `user_id` - The ID of the confirmed user
- `payload` - Additional event-specific data (intended_roles, tier, etc.)
- `opts` - Metadata options (correlation_id, causation_id)

## Raises

- `ArgumentError` if `user_id` is nil or empty
"""
def user_confirmed(user_id, payload \\ %{}, opts \\ [])

def user_confirmed(user_id, payload, opts)
    when is_binary(user_id) and byte_size(user_id) > 0 do
  base_payload = %{user_id: user_id}
  opts = Keyword.put_new(opts, :criticality, :critical)

  IntegrationEvent.new(
    :user_confirmed,
    @source_context,
    @entity_type,
    user_id,
    Map.merge(payload, base_payload),
    opts
  )
end

def user_confirmed(user_id, _payload, _opts) do
  raise ArgumentError,
        "user_confirmed/3 requires a non-empty user_id string, got: #{inspect(user_id)}"
end
```

Also update the `@moduledoc` to add `user_confirmed` to the events list.

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/accounts/domain/events/accounts_integration_events_test.exs`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/accounts/domain/events/accounts_integration_events_test.exs lib/klass_hero/accounts/domain/events/accounts_integration_events.ex
git commit -m "feat: add user_confirmed integration event factory

Critical integration event for the compensation path. Downstream
contexts use this to ensure profiles exist before first login."
```

---

### Task 4: Promote `user_confirmed` domain event to integration event

**Files:**
- Test: `test/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events_test.exs`
- Modify: `lib/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events.ex`
- Modify: `lib/klass_hero/application.ex:65-72`

- [ ] **Step 1: Write failing test**

Add a new `describe "handle/1 — :user_confirmed"` block to `test/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events_test.exs`, after the `user_anonymized` describe block:

```elixir
describe "handle/1 — :user_confirmed" do
  test "promotes to user_confirmed integration event" do
    user_id = Ecto.UUID.generate()

    domain_event =
      DomainEvent.new(:user_confirmed, user_id, :user, %{
        email: "test@example.com",
        name: "Test Provider",
        confirmed_at: ~U[2024-01-01 12:00:00Z],
        intended_roles: ["provider"],
        provider_subscription_tier: "professional"
      })

    assert :ok = PromoteIntegrationEvents.handle(domain_event)

    event = assert_integration_event_published(:user_confirmed)
    assert event.entity_id == user_id
    assert event.source_context == :accounts
    assert event.payload.user_id == user_id
    assert event.payload.intended_roles == ["provider"]
    assert event.payload.provider_subscription_tier == "professional"
    assert IntegrationEvent.critical?(event)
  end

  test "propagates publish failures" do
    user_id = Ecto.UUID.generate()

    domain_event =
      DomainEvent.new(:user_confirmed, user_id, :user, %{
        email: "test@example.com",
        name: "Test User",
        confirmed_at: ~U[2024-01-01 12:00:00Z],
        intended_roles: ["parent"]
      })

    TestIntegrationEventPublisher.configure_publish_error(:pubsub_down)

    assert {:error, :pubsub_down} = PromoteIntegrationEvents.handle(domain_event)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events_test.exs --max-failures 1`

Expected: FAIL — no matching clause for `:user_confirmed`.

- [ ] **Step 3: Add handler clause**

In `lib/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events.ex`, add before the closing `end` of the module (after the `user_anonymized` clause):

```elixir
def handle(%DomainEvent{event_type: :user_confirmed} = event) do
  # Trigger: user_confirmed domain event dispatched after email confirmation
  # Why: compensation path — downstream contexts verify/create profiles before first login
  # Outcome: publish integration event; propagate failure so caller knows
  event.aggregate_id
  |> AccountsIntegrationEvents.user_confirmed(event.payload)
  |> IntegrationEventPublishing.publish()
end
```

Also update the `@moduledoc` to mention `user_confirmed`.

- [ ] **Step 4: Register on Accounts DomainEventBus**

In `lib/klass_hero/application.ex`, the Accounts DomainEventBus handlers list (lines 65-71) should become:

```elixir
handlers: [
  {:user_registered,
   {KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
    :handle}, priority: 10},
  {:user_confirmed,
   {KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
    :handle}, priority: 10},
  {:user_anonymized,
   {KlassHero.Accounts.Adapters.Driven.Events.EventHandlers.PromoteIntegrationEvents,
    :handle}, priority: 10}
]

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events_test.exs`

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add test/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events_test.exs lib/klass_hero/accounts/adapters/driven/events/event_handlers/promote_integration_events.ex lib/klass_hero/application.ex
git commit -m "feat: promote user_confirmed to integration event

Registers user_confirmed on the Accounts DomainEventBus and promotes
it via PromoteIntegrationEvents for cross-context consumption."
```

---

### Task 5: ProviderEventHandler subscribes to `user_confirmed`

**Files:**
- Test: `test/klass_hero/provider/adapters/driven/events/provider_event_handler_test.exs`
- Modify: `lib/klass_hero/provider/adapters/driven/events/provider_event_handler.ex`
- Modify: `lib/klass_hero/application.ex` (Provider EventSubscriber topics)

- [ ] **Step 1: Write failing tests**

Add to `test/klass_hero/provider/adapters/driven/events/provider_event_handler_test.exs`:

After the `subscribed_events` or last describe block, add:

```elixir
describe "handle_event/1 for :user_confirmed" do
  test "creates provider profile when 'provider' in intended_roles" do
    user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

    event = build_user_confirmed_event(user)
    assert {:ok, _profile} = ProviderEventHandler.handle_event(event)

    assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
    assert profile.subscription_tier == :starter
  end

  test "creates provider profile with selected tier" do
    user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

    event = build_user_confirmed_event(user, provider_subscription_tier: "professional")
    assert {:ok, _profile} = ProviderEventHandler.handle_event(event)

    assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
    assert profile.subscription_tier == :professional
  end

  test "returns :ok when provider profile already exists (idempotent)" do
    user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

    # First call creates the profile
    registered_event = build_user_registered_event(user)
    assert {:ok, _profile} = ProviderEventHandler.handle_event(registered_event)

    # Second call via user_confirmed is idempotent
    confirmed_event = build_user_confirmed_event(user, provider_subscription_tier: "professional")
    assert :ok = ProviderEventHandler.handle_event(confirmed_event)

    # Only one profile exists
    assert {:ok, _profile} = Provider.get_provider_by_identity(user.id)
  end

  test "ignores event when 'provider' not in intended_roles" do
    user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:parent])

    event = build_user_confirmed_event(user, intended_roles: ["parent"])
    assert :ignore = ProviderEventHandler.handle_event(event)
  end
end

describe "subscribed_events/0" do
  test "includes :user_confirmed" do
    assert :user_confirmed in ProviderEventHandler.subscribed_events()
  end
end
```

Also add a helper at the bottom of the test module, alongside the existing `build_user_registered_event`:

```elixir
defp build_user_confirmed_event(user, opts \\ []) do
  intended_roles = Keyword.get(opts, :intended_roles, ["provider"])
  provider_tier = Keyword.get(opts, :provider_subscription_tier)

  %{
    event_type: :user_confirmed,
    entity_id: user.id,
    payload: %{
      intended_roles: intended_roles,
      name: user.name || "Test Provider",
      provider_subscription_tier: provider_tier
    }
  }
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/provider/adapters/driven/events/provider_event_handler_test.exs --max-failures 1`

Expected: FAIL — no matching clause for `:user_confirmed`.

- [ ] **Step 3: Add handler clause and update subscribed_events**

In `lib/klass_hero/provider/adapters/driven/events/provider_event_handler.ex`:

Update `subscribed_events`:

```elixir
def subscribed_events, do: [:user_registered, :user_confirmed, :user_anonymized]
```

Add new handler clause after the `user_registered` clause (after line 53):

```elixir
@impl true
def handle_event(%{event_type: :user_confirmed, entity_id: user_id, payload: payload}) do
  intended_roles = Map.get(payload, :intended_roles, [])
  business_name = Map.get(payload, :name, "")
  provider_tier = Map.get(payload, :provider_subscription_tier)

  # Trigger: user_confirmed event — compensation path for profile creation
  # Why: if user_registered delivery was delayed, this ensures the profile
  #      exists before the user's first authenticated session
  # Outcome: creates profile or returns :ok if already exists (idempotent)
  if "provider" in intended_roles do
    create_provider_profile_with_retry(user_id, business_name, provider_tier)
  else
    :ignore
  end
end
```

Update the `@moduledoc` to list `:user_confirmed` in the Subscribed Events section.

- [ ] **Step 4: Add PubSub topic to EventSubscriber**

In `lib/klass_hero/application.ex`, find the Provider EventSubscriber (around line 283-292) and add the topic:

```elixir
topics: [
  "integration:accounts:user_registered",
  "integration:accounts:user_confirmed",
  "integration:accounts:user_anonymized"
],
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/provider/adapters/driven/events/provider_event_handler_test.exs`

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add test/klass_hero/provider/adapters/driven/events/provider_event_handler_test.exs lib/klass_hero/provider/adapters/driven/events/provider_event_handler.ex lib/klass_hero/application.ex
git commit -m "feat: ProviderEventHandler subscribes to user_confirmed

Compensation path: if user_registered was delayed, user_confirmed
ensures the provider profile exists before the user's first login.
Idempotent — duplicate identity returns :ok."
```

---

### Task 6: FamilyEventHandler subscribes to `user_confirmed`

**Files:**
- Test: `test/klass_hero/family/adapters/driven/events/family_event_handler_test.exs`
- Modify: `lib/klass_hero/family/adapters/driven/events/family_event_handler.ex`
- Modify: `lib/klass_hero/application.ex` (Family EventSubscriber topics)

- [ ] **Step 1: Write failing tests**

Add to `test/klass_hero/family/adapters/driven/events/family_event_handler_test.exs`:

After the existing `describe "subscribed_events/0"` block, add:

```elixir
describe "handle_event/1 for :user_confirmed" do
  test "creates parent profile when 'parent' in intended_roles" do
    user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:parent])

    event = build_user_confirmed_event(user)
    assert {:ok, _profile} = FamilyEventHandler.handle_event(event)

    assert {:ok, _profile} = KlassHero.Family.get_parent_by_identity(user.id)
  end

  test "returns :ok when parent profile already exists (idempotent)" do
    user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:parent])

    # First call creates the profile
    registered_event = build_user_registered_event(user)
    assert {:ok, _profile} = FamilyEventHandler.handle_event(registered_event)

    # Second call via user_confirmed is idempotent
    confirmed_event = build_user_confirmed_event(user)
    assert :ok = FamilyEventHandler.handle_event(confirmed_event)
  end

  test "ignores event when 'parent' not in intended_roles" do
    user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

    event = build_user_confirmed_event(user, intended_roles: ["provider"])
    assert :ignore = FamilyEventHandler.handle_event(event)
  end
end
```

Also update the existing `describe "subscribed_events/0"` block to add:

```elixir
test "includes :user_confirmed" do
  assert :user_confirmed in FamilyEventHandler.subscribed_events()
end
```

Add helpers at the bottom of the test module:

```elixir
defp build_user_registered_event(user, opts \\ []) do
  intended_roles = Keyword.get(opts, :intended_roles, ["parent"])

  %{
    event_type: :user_registered,
    entity_id: user.id,
    payload: %{
      intended_roles: intended_roles,
      name: user.name || "Test User"
    }
  }
end

defp build_user_confirmed_event(user, opts \\ []) do
  intended_roles = Keyword.get(opts, :intended_roles, ["parent"])

  %{
    event_type: :user_confirmed,
    entity_id: user.id,
    payload: %{
      intended_roles: intended_roles,
      name: user.name || "Test User"
    }
  }
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/family/adapters/driven/events/family_event_handler_test.exs --max-failures 1`

Expected: FAIL — no matching clause for `:user_confirmed`.

- [ ] **Step 3: Add handler clause and update subscribed_events**

In `lib/klass_hero/family/adapters/driven/events/family_event_handler.ex`:

Update `subscribed_events`:

```elixir
def subscribed_events, do: [:user_registered, :user_confirmed, :user_anonymized]
```

Add new handler clause after the `user_registered` clause (after line 45):

```elixir
@impl true
def handle_event(%{event_type: :user_confirmed, entity_id: user_id, payload: payload}) do
  intended_roles = Map.get(payload, :intended_roles, [])

  # Trigger: user_confirmed event — compensation path for profile creation
  # Why: if user_registered delivery was delayed, this ensures the profile
  #      exists before the user's first authenticated session
  # Outcome: creates profile or returns :ok if already exists (idempotent)
  if "parent" in intended_roles do
    create_parent_profile_with_retry(user_id)
  else
    :ignore
  end
end
```

Update the `@moduledoc` to list `:user_confirmed` in the Subscribed Events section.

- [ ] **Step 4: Add PubSub topic to EventSubscriber**

In `lib/klass_hero/application.ex`, find the Family EventSubscriber (around line 272-281) and add the topic:

```elixir
topics: [
  "integration:accounts:user_registered",
  "integration:accounts:user_confirmed",
  "integration:accounts:user_anonymized"
],
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/family/adapters/driven/events/family_event_handler_test.exs`

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add test/klass_hero/family/adapters/driven/events/family_event_handler_test.exs lib/klass_hero/family/adapters/driven/events/family_event_handler.ex lib/klass_hero/application.ex
git commit -m "feat: FamilyEventHandler subscribes to user_confirmed

Compensation path: if user_registered was delayed, user_confirmed
ensures the parent profile exists before the user's first login.
Idempotent — duplicate identity returns :ok."
```

---

### Task 7: Integration test — registration to confirmation flow

**Files:**
- Create: `test/klass_hero/accounts/registration_confirmation_integration_test.exs`

- [ ] **Step 1: Write integration test**

Create `test/klass_hero/accounts/registration_confirmation_integration_test.exs`:

```elixir
defmodule KlassHero.Accounts.RegistrationConfirmationIntegrationTest do
  @moduledoc """
  Integration test verifying the full registration → confirmation flow
  creates the correct profiles with the right subscription tier.
  """

  use KlassHero.DataCase, async: false

  alias KlassHero.Accounts
  alias KlassHero.Family
  alias KlassHero.Provider

  describe "provider registration → confirmation" do
    test "provider profile exists with correct tier after registration" do
      {:ok, user} =
        Accounts.register_user(%{
          "name" => "Test Provider",
          "email" => "provider-#{System.unique_integer([:positive])}@example.com",
          "intended_roles" => ["provider"],
          "provider_subscription_tier" => "professional"
        })

      # Allow async event processing to complete
      Process.sleep(100)

      assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
      assert profile.subscription_tier == :professional
    end

    test "parent profile exists after registration" do
      {:ok, user} =
        Accounts.register_user(%{
          "name" => "Test Parent",
          "email" => "parent-#{System.unique_integer([:positive])}@example.com",
          "intended_roles" => ["parent"]
        })

      # Allow async event processing to complete
      Process.sleep(100)

      assert {:ok, _profile} = Family.get_parent_by_identity(user.id)
    end

    test "both profiles exist for dual-role registration" do
      {:ok, user} =
        Accounts.register_user(%{
          "name" => "Dual Role User",
          "email" => "dual-#{System.unique_integer([:positive])}@example.com",
          "intended_roles" => ["parent", "provider"],
          "provider_subscription_tier" => "starter"
        })

      # Allow async event processing to complete
      Process.sleep(100)

      assert {:ok, _parent} = Family.get_parent_by_identity(user.id)
      assert {:ok, provider} = Provider.get_provider_by_identity(user.id)
      assert provider.subscription_tier == :starter
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `mix test test/klass_hero/accounts/registration_confirmation_integration_test.exs`

Expected: All tests pass — profiles are created via the `user_registered` event path.

- [ ] **Step 3: Commit**

```bash
git add test/klass_hero/accounts/registration_confirmation_integration_test.exs
git commit -m "test: add integration test for registration → profile creation flow

Verifies that provider/parent profiles are created with the correct
tier through the full event chain after registration."
```

---

### Task 8: Final verification

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

Run: `mix test`

Expected: All tests pass, zero failures.

- [ ] **Step 2: Run precommit checks**

Run: `mix precommit`

Expected: Compilation with no warnings, formatting clean, all tests pass.

- [ ] **Step 3: Verify the fix end-to-end manually (optional)**

If the Phoenix server is running, use Tidewave to verify:

```elixir
# Simulate: register a provider user
{:ok, user} = KlassHero.Accounts.register_user(%{
  "name" => "Test Provider",
  "email" => "provider-test-#{System.unique_integer([:positive])}@example.com",
  "intended_roles" => ["provider"],
  "provider_subscription_tier" => "professional"
})

# Verify tier is persisted
user.provider_subscription_tier
# => "professional"

# Verify provider profile was created via user_registered event
Process.sleep(500)
KlassHero.Provider.get_provider_by_identity(user.id)
# => {:ok, %{subscription_tier: :professional, ...}}
```
