# Staff Invitation Saga Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Use TDD (superpowers:test-driven-development) and idiomatic-elixir skills throughout.

**Goal:** When a business adds a staff member with an email, automatically send an invitation email; on registration, create a `:staff_provider` account linked to the business (no independent ProviderProfile).

**Architecture:** Choreography-based saga crossing Provider and Accounts bounded contexts. Saga state tracked as `invitation_status` on the `staff_members` table. All cross-context events are critical (Oban-backed, idempotent via `processed_events`). Pure domain function for state machine transitions.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Oban, Swoosh, PostgreSQL

**Spec:** `docs/superpowers/specs/2026-03-21-staff-invitation-saga-design.md`

---

## Task 1: Database Migration — New Staff Member Columns

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_invitation_fields_to_staff_members.exs`

- [ ] **Step 1: Write the migration**

```elixir
defmodule KlassHero.Repo.Migrations.AddInvitationFieldsToStaffMembers do
  use Ecto.Migration

  def change do
    alter table(:staff_members) do
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :invitation_status, :string
      add :invitation_token_hash, :binary
      add :invitation_sent_at, :utc_datetime_usec
    end

    create index(:staff_members, [:user_id])
    create index(:staff_members, [:invitation_token_hash], unique: true)
    create index(:staff_members, [:invitation_status])
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully, no errors.

- [ ] **Step 3: Commit**

```bash
git add priv/repo/migrations/*_add_invitation_fields_to_staff_members.exs
git commit -m "feat: add invitation fields to staff_members table"
```

---

## Task 2: Domain Model — Invitation State Machine

**Files:**
- Modify: `lib/klass_hero/provider/domain/models/staff_member.ex`
- Create: `test/klass_hero/provider/domain/models/staff_member_invitation_test.exs`

- [ ] **Step 1: Write failing tests for transition_invitation/2**

```elixir
defmodule KlassHero.Provider.Domain.Models.StaffMemberInvitationTest do
  use ExUnit.Case, async: true

  alias KlassHero.Provider.Domain.Models.StaffMember

  describe "transition_invitation/2" do
    test "nil -> :pending succeeds" do
      staff = build_staff_member(invitation_status: nil)
      assert {:ok, %StaffMember{invitation_status: :pending}} = StaffMember.transition_invitation(staff, :pending)
    end

    test ":pending -> :sent succeeds" do
      staff = build_staff_member(invitation_status: :pending)
      assert {:ok, %StaffMember{invitation_status: :sent}} = StaffMember.transition_invitation(staff, :sent)
    end

    test ":pending -> :failed succeeds" do
      staff = build_staff_member(invitation_status: :pending)
      assert {:ok, %StaffMember{invitation_status: :failed}} = StaffMember.transition_invitation(staff, :failed)
    end

    test ":sent -> :accepted succeeds" do
      staff = build_staff_member(invitation_status: :sent)
      assert {:ok, %StaffMember{invitation_status: :accepted}} = StaffMember.transition_invitation(staff, :accepted)
    end

    test ":sent -> :expired succeeds" do
      staff = build_staff_member(invitation_status: :sent)
      assert {:ok, %StaffMember{invitation_status: :expired}} = StaffMember.transition_invitation(staff, :expired)
    end

    test ":failed -> :pending succeeds (resend)" do
      staff = build_staff_member(invitation_status: :failed)
      assert {:ok, %StaffMember{invitation_status: :pending}} = StaffMember.transition_invitation(staff, :pending)
    end

    test ":expired -> :pending succeeds (resend)" do
      staff = build_staff_member(invitation_status: :expired)
      assert {:ok, %StaffMember{invitation_status: :pending}} = StaffMember.transition_invitation(staff, :pending)
    end

    test ":accepted -> :pending fails (invalid)" do
      staff = build_staff_member(invitation_status: :accepted)
      assert {:error, :invalid_invitation_transition} = StaffMember.transition_invitation(staff, :pending)
    end

    test ":sent -> :pending fails (invalid)" do
      staff = build_staff_member(invitation_status: :sent)
      assert {:error, :invalid_invitation_transition} = StaffMember.transition_invitation(staff, :pending)
    end

    test "nil -> :sent fails (must go through :pending)" do
      staff = build_staff_member(invitation_status: nil)
      assert {:error, :invalid_invitation_transition} = StaffMember.transition_invitation(staff, :sent)
    end
  end

  defp build_staff_member(overrides) do
    defaults = %{
      id: Ecto.UUID.generate(),
      provider_id: Ecto.UUID.generate(),
      first_name: "Jane",
      last_name: "Doe"
    }

    struct!(StaffMember, Map.merge(defaults, Map.new(overrides)))
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/provider/domain/models/staff_member_invitation_test.exs`
Expected: FAIL — `transition_invitation/2` is undefined.

- [ ] **Step 3: Add new fields to StaffMember struct and implement transition_invitation/2**

In `lib/klass_hero/provider/domain/models/staff_member.ex`:

Add to `defstruct` (after existing fields, before `active: true`):
```elixir
:user_id,
:invitation_status,
:invitation_token_hash,
:invitation_sent_at,
```

Add to `@type t` definition:
```elixir
user_id: String.t() | nil,
invitation_status: :pending | :sent | :failed | :accepted | :expired | nil,
invitation_token_hash: binary() | nil,
invitation_sent_at: DateTime.t() | nil,
```

Add the transition function (at end of module, before final `end`):
```elixir
@valid_invitation_transitions %{
  nil => [:pending],
  :pending => [:sent, :failed],
  :sent => [:accepted, :expired],
  :failed => [:pending],
  :expired => [:pending]
}

@doc """
Transitions the invitation status according to the valid state machine.
Returns {:ok, updated_staff_member} or {:error, :invalid_invitation_transition}.
"""
@spec transition_invitation(t(), atom()) :: {:ok, t()} | {:error, :invalid_invitation_transition}
def transition_invitation(%__MODULE__{} = staff_member, new_status) do
  allowed = Map.get(@valid_invitation_transitions, staff_member.invitation_status, [])

  if new_status in allowed do
    {:ok, %{staff_member | invitation_status: new_status}}
  else
    {:error, :invalid_invitation_transition}
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/provider/domain/models/staff_member_invitation_test.exs`
Expected: All 10 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/provider/domain/models/staff_member.ex test/klass_hero/provider/domain/models/staff_member_invitation_test.exs
git commit -m "feat: add invitation state machine to StaffMember domain model"
```

---

## Task 3: Persistence Layer — Schema, Mapper, Repository Updates

**Files:**
- Modify: `lib/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema.ex`
- Modify: `lib/klass_hero/provider/adapters/driven/persistence/mappers/staff_member_mapper.ex`
- Modify: `lib/klass_hero/provider/adapters/driven/persistence/repositories/staff_member_repository.ex`
- Modify: `lib/klass_hero/provider/domain/ports/for_storing_staff_members.ex`
- Create: `test/klass_hero/provider/adapters/driven/persistence/repositories/staff_member_repository_invitation_test.exs`

- [ ] **Step 1: Write failing test for repository token lookup**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.StaffMemberRepositoryInvitationTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.StaffMemberRepository
  alias KlassHero.Provider.Domain.Models.StaffMember

  import KlassHero.ProviderFixtures

  describe "get_by_token_hash/1" do
    test "returns staff member when token hash matches and status is :sent" do
      provider = provider_profile_fixture()
      raw_token = :crypto.strong_rand_bytes(32)
      token_hash = :crypto.hash(:sha256, raw_token)

      staff = staff_member_fixture(%{
        provider_id: provider.id,
        invitation_token_hash: token_hash,
        invitation_status: "sent",
        invitation_sent_at: DateTime.utc_now()
      })

      assert {:ok, %StaffMember{id: id}} = StaffMemberRepository.get_by_token_hash(token_hash)
      assert id == staff.id
    end

    test "returns error when no matching token hash" do
      assert {:error, :not_found} = StaffMemberRepository.get_by_token_hash(:crypto.hash(:sha256, "bogus"))
    end

    test "returns error when status is not :sent" do
      provider = provider_profile_fixture()
      raw_token = :crypto.strong_rand_bytes(32)
      token_hash = :crypto.hash(:sha256, raw_token)

      _staff = staff_member_fixture(%{
        provider_id: provider.id,
        invitation_token_hash: token_hash,
        invitation_status: "pending"
      })

      assert {:error, :not_found} = StaffMemberRepository.get_by_token_hash(token_hash)
    end
  end

  describe "get_active_by_user/1" do
    test "returns staff member when user_id matches and active" do
      provider = provider_profile_fixture()
      user_id = Ecto.UUID.generate()

      staff = staff_member_fixture(%{
        provider_id: provider.id,
        user_id: user_id,
        active: true
      })

      assert {:ok, %StaffMember{id: id}} = StaffMemberRepository.get_active_by_user(user_id)
      assert id == staff.id
    end

    test "returns error when user not found or inactive" do
      assert {:error, :not_found} = StaffMemberRepository.get_active_by_user(Ecto.UUID.generate())
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/repositories/staff_member_repository_invitation_test.exs`
Expected: FAIL — functions don't exist.

- [ ] **Step 3: Update StaffMemberSchema with new fields**

In `lib/klass_hero/provider/adapters/driven/persistence/schemas/staff_member_schema.ex`, add to schema block (after `field :active, :boolean, default: true`):
```elixir
field :invitation_status, :string
field :invitation_token_hash, :binary
field :invitation_sent_at, :utc_datetime_usec

belongs_to :user, KlassHero.Accounts.Adapters.Driven.Persistence.Schemas.User, type: :binary_id
```

Add an `invitation_changeset/2` function for updating invitation fields only:
```elixir
def invitation_changeset(staff_member, attrs) do
  staff_member
  |> cast(attrs, [:invitation_status, :invitation_token_hash, :invitation_sent_at, :user_id])
  |> validate_inclusion(:invitation_status, ~w(pending sent failed accepted expired))
end
```

Update `create_changeset/2` to also accept `invitation_status`, `invitation_token_hash`:
Add to the cast list: `:invitation_status, :invitation_token_hash`

Update `edit_changeset/2` to also cast invitation fields so that `StaffMemberRepository.update/1` can persist invitation state changes:
Add to the cast list: `:invitation_status, :invitation_token_hash, :invitation_sent_at, :user_id`
Add `|> validate_inclusion(:invitation_status, ~w(pending sent failed accepted expired))`

- [ ] **Step 4: Update StaffMemberMapper with new fields**

In `lib/klass_hero/provider/adapters/driven/persistence/mappers/staff_member_mapper.ex`:

Update `to_domain/1` to include: `user_id`, `invitation_status` (atomize), `invitation_token_hash`, `invitation_sent_at`.

Update `to_schema/1` to include: `user_id`, `invitation_status` (stringify), `invitation_token_hash`, `invitation_sent_at`.

Atomize invitation_status:
```elixir
defp atomize_invitation_status(nil), do: nil
defp atomize_invitation_status(status) when is_binary(status), do: String.to_existing_atom(status)
defp atomize_invitation_status(status) when is_atom(status), do: status
```

- [ ] **Step 5: Update port with new callbacks**

In `lib/klass_hero/provider/domain/ports/for_storing_staff_members.ex`, add:
```elixir
@callback get_by_token_hash(binary()) :: {:ok, StaffMember.t()} | {:error, :not_found}
@callback get_active_by_user(String.t()) :: {:ok, StaffMember.t()} | {:error, :not_found}
```

- [ ] **Step 6: Implement new repository functions**

In `lib/klass_hero/provider/adapters/driven/persistence/repositories/staff_member_repository.ex`, add:

```elixir
@impl true
def get_by_token_hash(token_hash) do
  query =
    from s in StaffMemberSchema,
      where: s.invitation_token_hash == ^token_hash and s.invitation_status == "sent"

  case Repo.one(query) do
    nil -> {:error, :not_found}
    schema -> {:ok, StaffMemberMapper.to_domain(schema)}
  end
end

@impl true
def get_active_by_user(user_id) do
  query =
    from s in StaffMemberSchema,
      where: s.user_id == ^user_id and s.active == true,
      limit: 1

  case Repo.one(query) do
    nil -> {:error, :not_found}
    schema -> {:ok, StaffMemberMapper.to_domain(schema)}
  end
end
```

- [ ] **Step 7: Update test fixtures to support new fields**

In `test/support/fixtures/provider_fixtures.ex`, update `staff_member_fixture/1`:
1. Add invitation fields (`invitation_status`, `invitation_token_hash`, `invitation_sent_at`, `user_id`) to the cast list in `create_changeset/2` so they can be set during test inserts
2. Alternatively, after the initial insert, apply an `invitation_changeset` update when invitation-specific attrs are provided. The second approach is cleaner (doesn't leak test concerns into production changesets) — pattern:

```elixir
schema =
  if Map.has_key?(attrs, :invitation_status) do
    schema
    |> StaffMemberSchema.invitation_changeset(Map.take(attrs, [:invitation_status, :invitation_token_hash, :invitation_sent_at, :user_id]))
    |> Repo.update!()
  else
    schema
  end
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `mix test test/klass_hero/provider/adapters/driven/persistence/repositories/staff_member_repository_invitation_test.exs`
Expected: All tests PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/persistence/ lib/klass_hero/provider/domain/ports/ test/
git commit -m "feat: add invitation fields to staff member persistence layer"
```

---

## Task 4: UserRole — Add :staff_provider Role

**Files:**
- Modify: `lib/klass_hero/accounts/types/user_role.ex`
- Create: `test/klass_hero/accounts/types/user_role_staff_provider_test.exs`

- [ ] **Step 1: Write failing test**

```elixir
defmodule KlassHero.Accounts.Types.UserRoleStaffProviderTest do
  use ExUnit.Case, async: true

  alias KlassHero.Accounts.Types.UserRole

  test ":staff_provider is a valid role" do
    assert UserRole.valid_role?(:staff_provider)
  end

  test ":staff_provider can be converted to string" do
    assert {:ok, "staff_provider"} = UserRole.to_string(:staff_provider)
  end

  test ":staff_provider can be parsed from string" do
    assert {:ok, :staff_provider} = UserRole.from_string("staff_provider")
  end

  test ":staff_provider has permissions" do
    assert is_list(UserRole.permissions(:staff_provider))
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/accounts/types/user_role_staff_provider_test.exs`
Expected: FAIL — `:staff_provider` not in valid roles.

- [ ] **Step 3: Add :staff_provider to UserRole**

In `lib/klass_hero/accounts/types/user_role.ex`:

1. Update `@valid_roles` (line 36): `@valid_roles [:parent, :provider, :staff_provider]`
2. Update `@type t` to include `:staff_provider`
3. Add to `@role_permissions` map (after provider entry):
```elixir
staff_provider: [
  :view_assigned_programs,
  :view_staff_dashboard,
  :manage_own_profile
]
```

Note: The generic `to_string/1` and `from_string/1` functions operate over `@valid_roles` automatically — no new clauses needed for those.

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/accounts/types/user_role_staff_provider_test.exs`
Expected: All 4 tests PASS.

- [ ] **Step 5: Run full test suite to check for regressions**

Run: `mix test`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/accounts/types/user_role.ex test/klass_hero/accounts/types/user_role_staff_provider_test.exs
git commit -m "feat: add :staff_provider role to UserRole system"
```

---

## Task 5: Scope Enhancement — Add staff_member Field

**Files:**
- Modify: `lib/klass_hero/accounts/scope.ex`
- Modify: `lib/klass_hero/provider.ex`
- Create: `test/klass_hero/accounts/scope_staff_provider_test.exs`

- [ ] **Step 1: Write failing test for scope resolution**

```elixir
defmodule KlassHero.Accounts.ScopeStaffProviderTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Accounts.Scope

  import KlassHero.AccountsFixtures
  import KlassHero.ProviderFixtures

  describe "resolve_roles/1 with staff_provider" do
    test "adds :staff_provider role when user is active staff member" do
      user = user_fixture()
      provider = provider_profile_fixture()
      _staff = staff_member_fixture(%{provider_id: provider.id, user_id: user.id, active: true})

      scope = Scope.for_user(user) |> Scope.resolve_roles()

      assert :staff_provider in scope.roles
      assert scope.staff_member != nil
      assert scope.staff_member.provider_id == provider.id
    end

    test "does not add :staff_provider when user has no staff membership" do
      user = user_fixture()

      scope = Scope.for_user(user) |> Scope.resolve_roles()

      refute :staff_provider in scope.roles
      assert scope.staff_member == nil
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/accounts/scope_staff_provider_test.exs`
Expected: FAIL — `staff_member` key not in Scope struct.

- [ ] **Step 3: Add Provider.get_active_staff_member_by_user/1 to Provider facade**

In `lib/klass_hero/provider.ex`, add a new public function (in the staff member section):
```elixir
@doc """
Returns the active staff member record linked to the given user ID.
Used by Scope to resolve :staff_provider role.
"""
@spec get_active_staff_member_by_user(String.t()) :: {:ok, StaffMember.t()} | {:error, :not_found}
def get_active_staff_member_by_user(user_id) do
  @staff_repository.get_active_by_user(user_id)
end
```

Also add new public functions for token lookup, profile access, and expiry:
```elixir
@doc """
Returns the staff member matching the given invitation token hash,
only if invitation_status is :sent. Used by the invitation registration flow.
"""
@spec get_staff_member_by_token_hash(binary()) :: {:ok, StaffMember.t()} | {:error, :not_found}
def get_staff_member_by_token_hash(token_hash) do
  @staff_repository.get_by_token_hash(token_hash)
end

@doc """
Returns the provider profile by ID. Used by staff dashboard to display business info.
"""
@spec get_provider_profile(String.t()) :: {:ok, ProviderProfile.t()} | {:error, :not_found}
def get_provider_profile(provider_id) do
  @provider_repository.get(provider_id)
end

@doc """
Transitions a staff member's invitation status to :expired.
Called by the invitation LiveView on lazy expiry detection.
"""
@spec expire_staff_invitation(String.t()) :: {:ok, StaffMember.t()} | {:error, term()}
def expire_staff_invitation(staff_member_id) do
  with {:ok, staff} <- @staff_repository.get(staff_member_id),
       {:ok, updated} <- StaffMember.transition_invitation(staff, :expired) do
    @staff_repository.update(updated)
  end
end
```

- [ ] **Step 4: Update Scope struct and resolve_roles/1**

In `lib/klass_hero/accounts/scope.ex`:

Update struct (line 23-26):
```elixir
defstruct user: nil, roles: [], parent: nil, provider: nil, staff_member: nil
```

Update `resolve_roles/1` to add a third check after the provider check:
```elixir
{staff_member, roles} =
  case Provider.get_active_staff_member_by_user(user.id) do
    {:ok, staff} -> {staff, [:staff_provider | roles]}
    {:error, :not_found} -> {nil, roles}
  end
```

And set `staff_member: staff_member` in the returned struct.

Also add convenience function:
```elixir
def staff_provider?(%__MODULE__{roles: roles}), do: :staff_provider in roles
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/accounts/scope_staff_provider_test.exs`
Expected: All tests PASS.

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: All tests PASS (existing scope tests should still work — new field defaults to nil).

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/accounts/scope.ex lib/klass_hero/provider.ex test/klass_hero/accounts/scope_staff_provider_test.exs
git commit -m "feat: add :staff_provider role resolution to Scope"
```

---

## Task 6: Event Factories — Integration Events

**Files:**
- Modify: `lib/klass_hero/provider/domain/events/provider_integration_events.ex`
- Modify: `lib/klass_hero/accounts/domain/events/accounts_integration_events.ex`
- Create: `test/klass_hero/provider/domain/events/provider_integration_events_test.exs` (if not exists)
- Create: `test/klass_hero/accounts/domain/events/accounts_integration_events_staff_test.exs`

- [ ] **Step 1: Write failing tests for Provider integration event factory**

Test that `ProviderIntegrationEvents.staff_member_invited/3` creates a properly structured `IntegrationEvent`.

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `staff_member_invited/3` undefined.

- [ ] **Step 3: Implement staff_member_invited factory in ProviderIntegrationEvents**

Follow the pattern from `subscription_tier_changed/3`. Create a `:staff_member_invited` event with:
- `source_context: :provider`
- `entity_type: :staff_member`
- `criticality: :critical`
- Payload: `staff_member_id`, `provider_id`, `email`, `first_name`, `last_name`, `business_name`, `raw_token`

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Write failing tests for Accounts integration event factories**

Test `AccountsIntegrationEvents.staff_invitation_sent/3`, `staff_invitation_failed/3`, `staff_user_registered/3`.

- [ ] **Step 6: Run tests to verify they fail**

- [ ] **Step 7: Implement three Accounts event factories**

Follow the pattern from `user_registered/3`. All critical. Payloads per spec:
- `staff_invitation_sent`: `{staff_member_id, provider_id}`
- `staff_invitation_failed`: `{staff_member_id, provider_id, reason}`
- `staff_user_registered`: `{user_id, staff_member_id, provider_id}`

- [ ] **Step 8: Run all event tests**

Run: `mix test test/klass_hero/provider/domain/events/ test/klass_hero/accounts/domain/events/`
Expected: All PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/klass_hero/provider/domain/events/ lib/klass_hero/accounts/domain/events/ test/
git commit -m "feat: add integration event factories for staff invitation saga"
```

---

## Task 7: CreateStaffMember — Token Generation & Event Emission

**Files:**
- Modify: `lib/klass_hero/provider/application/use_cases/staff_members/create_staff_member.ex`
- Create: `test/klass_hero/provider/application/use_cases/staff_members/create_staff_member_invitation_test.exs`

- [ ] **Step 1: Write failing test — staff member with email emits event**

Test that calling `CreateStaffMember.execute/1` with an email attribute:
- Sets `invitation_status: :pending`
- Generates and stores `invitation_token_hash`
- Returns the raw token in the result (or emits an integration event with it)

Use test event publisher to capture emitted events.

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — no token generation or event emission in current use case.

- [ ] **Step 3: Implement token generation and event emission**

In `create_staff_member.ex`:
1. After domain validation, if `email` is present and non-empty:
   - Generate raw token: `raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)`
   - Hash it: `token_hash = :crypto.hash(:sha256, raw_token)`
   - Add `invitation_token_hash: token_hash` and `invitation_status: :pending` to the attrs before persisting
2. After successful persistence, if email was present:
   - Look up the provider's business_name for the event payload
   - Emit `:staff_member_invited` critical integration event with raw_token in payload
3. If email is nil/empty, persist normally without invitation fields (display-only staff member)

- [ ] **Step 4: Write test — staff member without email does NOT emit event**

Verify that creating a staff member without email does not emit any event and leaves `invitation_status` as `nil`.

- [ ] **Step 5: Run all tests**

Run: `mix test test/klass_hero/provider/application/use_cases/staff_members/`
Expected: All PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/provider/application/use_cases/staff_members/create_staff_member.ex test/
git commit -m "feat: generate invitation token and emit event on staff member creation"
```

---

## Task 8: Email Templates — UserNotifier

**Files:**
- Modify: `lib/klass_hero/accounts/user_notifier.ex`
- Create: `test/klass_hero/accounts/user_notifier_staff_test.exs`

- [ ] **Step 1: Write failing test for deliver_staff_invitation/3**

```elixir
test "delivers staff invitation email with registration link" do
  assert {:ok, email} =
    UserNotifier.deliver_staff_invitation(
      "staff@example.com",
      %{business_name: "Fun Academy", first_name: "Jane"},
      "http://localhost:4000/users/staff-invitation/test-token"
    )

  assert email.to == [{"", "staff@example.com"}]
  assert email.subject =~ "Fun Academy"
  assert email.text_body =~ "test-token"
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — function undefined.

- [ ] **Step 3: Implement deliver_staff_invitation/3**

In `lib/klass_hero/accounts/user_notifier.ex`, add:
```elixir
def deliver_staff_invitation(email, %{business_name: business_name, first_name: first_name}, url) do
  deliver(email, "You've been invited to join #{business_name} on Klass Hero", """
  Hi #{first_name},

  #{business_name} has invited you to join their team on Klass Hero.

  Klass Hero is a platform for managing afterschool activities, camps, and class trips.

  Click the link below to complete your registration:

  #{url}

  This invitation expires in 7 days.

  If you did not expect this invitation, you can ignore this email.
  """)
end
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Write failing test for deliver_staff_added_notification/2**

Test notification email for existing users — different subject and body, no registration link.

- [ ] **Step 6: Implement deliver_staff_added_notification/2**

```elixir
def deliver_staff_added_notification(email, %{business_name: business_name}) do
  deliver(email, "You've been added to #{business_name}'s team on Klass Hero", """
  Hi,

  #{business_name} has added you to their team on Klass Hero.

  You can view your assigned programs on your staff dashboard:

  #{KlassHeroWeb.Endpoint.url()}/staff/dashboard

  If you did not expect this, please contact #{business_name} directly.
  """)
end
```

- [ ] **Step 7: Run all notifier tests**

Run: `mix test test/klass_hero/accounts/user_notifier_staff_test.exs`
Expected: All PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/klass_hero/accounts/user_notifier.ex test/klass_hero/accounts/user_notifier_staff_test.exs
git commit -m "feat: add staff invitation and notification email templates"
```

---

## Task 9: StaffInvitationHandler — Accounts-Side Event Handler

**Files:**
- Create: `lib/klass_hero/accounts/adapters/driven/events/staff_invitation_handler.ex`
- Create: `test/klass_hero/accounts/adapters/driven/events/staff_invitation_handler_test.exs`

- [ ] **Step 1: Write failing test — happy path (new user)**

Test that receiving a `:staff_member_invited` integration event with an email that does NOT belong to an existing user:
- Sends an invitation email (capture with Swoosh test adapter)
- Emits `:staff_invitation_sent` integration event

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — module doesn't exist.

- [ ] **Step 3: Implement StaffInvitationHandler — new user path**

```elixir
defmodule KlassHero.Accounts.Adapters.Driven.Events.StaffInvitationHandler do
  @behaviour KlassHero.Shared.Domain.Ports.ForHandlingEvents

  alias KlassHero.Accounts
  alias KlassHero.Accounts.UserNotifier
  alias KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents
  alias KlassHero.Shared.IntegrationEventPublishing

  @impl true
  def subscribed_events, do: [:staff_member_invited]

  @impl true
  def handle_event(%{event_type: :staff_member_invited, payload: payload}) do
    # Payload keys may be strings after Oban serialization — normalize to atoms
    payload = Map.new(payload, fn {k, v} -> {to_existing_atom(k), v} end)

    %{email: email, staff_member_id: staff_member_id, provider_id: provider_id,
      first_name: first_name, business_name: business_name, raw_token: raw_token} = payload

    case Accounts.get_user_by_email(email) do
      nil ->
        url = "#{KlassHeroWeb.Endpoint.url()}/users/staff-invitation/#{raw_token}"
        case UserNotifier.deliver_staff_invitation(email, %{business_name: business_name, first_name: first_name}, url) do
          {:ok, _} ->
            emit_sent(staff_member_id, provider_id)
            :ok
          {:error, reason} ->
            emit_failed(staff_member_id, provider_id, inspect(reason))
            :ok
        end

      user ->
        UserNotifier.deliver_staff_added_notification(email, %{business_name: business_name})
        emit_registered(user.id, staff_member_id, provider_id)
        :ok
    end
  end

  defp to_existing_atom(key) when is_atom(key), do: key
  defp to_existing_atom(key) when is_binary(key), do: String.to_existing_atom(key)

  defp emit_sent(staff_member_id, provider_id) do
    event = AccountsIntegrationEvents.staff_invitation_sent(staff_member_id, %{provider_id: provider_id}, [])
    IntegrationEventPublishing.publish_critical(event, "staff_invitation_sent")
  end

  defp emit_failed(staff_member_id, provider_id, reason) do
    event = AccountsIntegrationEvents.staff_invitation_failed(staff_member_id, %{provider_id: provider_id, reason: reason}, [])
    IntegrationEventPublishing.publish_critical(event, "staff_invitation_failed")
  end

  defp emit_registered(user_id, staff_member_id, provider_id) do
    event = AccountsIntegrationEvents.staff_user_registered(user_id, %{staff_member_id: staff_member_id, provider_id: provider_id}, [])
    IntegrationEventPublishing.publish_critical(event, "staff_user_registered")
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Write failing test — existing user path**

Test that when the email belongs to an existing user:
- Sends notification email (not invitation)
- Emits `:staff_user_registered` immediately

- [ ] **Step 6: Implement and verify existing user path passes**

- [ ] **Step 7: Write failing test — email failure (compensation)**

Test that when email delivery fails:
- Emits `:staff_invitation_failed` with reason

- [ ] **Step 8: Implement and verify compensation path passes**

- [ ] **Step 9: Run all handler tests**

Run: `mix test test/klass_hero/accounts/adapters/driven/events/staff_invitation_handler_test.exs`
Expected: All PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/klass_hero/accounts/adapters/driven/events/staff_invitation_handler.ex test/
git commit -m "feat: implement StaffInvitationHandler for accounts context"
```

---

## Task 10: Provider-Side Event Handlers — Sent/Failed/Registered

**Files:**
- Create: `lib/klass_hero/provider/adapters/driven/events/staff_invitation_status_handler.ex`
- Create: `test/klass_hero/provider/adapters/driven/events/staff_invitation_status_handler_test.exs`

- [ ] **Step 1: Write failing test — :staff_invitation_sent updates status**

Test that receiving `:staff_invitation_sent` transitions the staff member's `invitation_status` from `:pending` to `:sent` and sets `invitation_sent_at`.

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement handler for :staff_invitation_sent**

Look up staff member by ID, call `StaffMember.transition_invitation/2`, persist update via repository.

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Write failing test — :staff_invitation_failed (compensation)**

Test that receiving `:staff_invitation_failed` transitions status from `:pending` to `:failed`.

- [ ] **Step 6: Implement and verify**

- [ ] **Step 7: Write failing test — :staff_user_registered links user**

Test that receiving `:staff_user_registered` sets `user_id` on the staff member and transitions status to `:accepted`.

- [ ] **Step 8: Implement and verify**

- [ ] **Step 9: Write idempotency test**

Test that processing the same event twice (e.g., `:staff_user_registered` with same user_id) is a no-op.

- [ ] **Step 10: Run all handler tests**

Run: `mix test test/klass_hero/provider/adapters/driven/events/staff_invitation_status_handler_test.exs`
Expected: All PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/events/staff_invitation_status_handler.ex test/
git commit -m "feat: implement provider-side staff invitation status handler"
```

---

## Task 11: Event Wiring — Application & Config

**Files:**
- Modify: `lib/klass_hero/application.ex`
- Modify: `config/config.exs`

- [ ] **Step 1: Wire StaffInvitationHandler as Accounts integration event subscriber**

In `lib/klass_hero/application.ex`, add a new `EventSubscriber` child spec (in the integration event subscribers section):

```elixir
Supervisor.child_spec(
  {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
   handler: KlassHero.Accounts.Adapters.Driven.Events.StaffInvitationHandler,
   topics: ["integration:provider:staff_member_invited"],
   message_tag: :integration_event,
   event_label: "Integration event"},
  id: :staff_invitation_event_subscriber
)
```

- [ ] **Step 2: Wire StaffInvitationStatusHandler as Provider integration event subscriber**

Add another `EventSubscriber` child spec:

```elixir
Supervisor.child_spec(
  {KlassHero.Shared.Adapters.Driven.Events.EventSubscriber,
   handler: KlassHero.Provider.Adapters.Driven.Events.StaffInvitationStatusHandler,
   topics: [
     "integration:accounts:staff_invitation_sent",
     "integration:accounts:staff_invitation_failed",
     "integration:accounts:staff_user_registered"
   ],
   message_tag: :integration_event,
   event_label: "Integration event"},
  id: :staff_invitation_status_subscriber
)
```

- [ ] **Step 3: Register critical event handlers in config**

In `config/config.exs`, add entries to the `critical_event_handler_registry` for all four new critical events, mapping each to its handler.

- [ ] **Step 4: Run full test suite**

Run: `mix test`
Expected: All PASS — event wiring doesn't break existing tests.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/application.ex config/config.exs
git commit -m "feat: wire staff invitation saga event subscribers and critical handlers"
```

---

## Task 12: Auth & Router — :staff_provider Access

**Files:**
- Modify: `lib/klass_hero_web/user_auth.ex`
- Modify: `lib/klass_hero_web/router.ex`

- [ ] **Step 1: Add require_staff_provider mount hook**

In `lib/klass_hero_web/user_auth.ex`, add a new `on_mount` clause:
```elixir
def on_mount(:require_staff_provider, _params, _session, socket) do
  if Scope.staff_provider?(socket.assigns.current_scope) do
    {:cont, socket}
  else
    {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/users/log-in")}
  end
end
```

- [ ] **Step 2: Add :require_staff_provider live_session to router**

In `lib/klass_hero_web/router.ex`, add new live_session block (before `:require_admin`):
```elixir
live_session :require_staff_provider,
  on_mount: [
    {KlassHeroWeb.UserAuth, :require_authenticated},
    {KlassHeroWeb.UserAuth, :require_staff_provider},
    {KlassHeroWeb.Hooks.RestoreLocale, :restore_locale}
  ] do
  live "/staff/dashboard", StaffDashboardLive, :index
end
```

Also add the invitation registration route to the `:current_user` live_session (existing optional-auth session):
```elixir
live "/users/staff-invitation/:token", UserLive.StaffInvitation, :new
```

- [ ] **Step 3: Run full test suite**

Run: `mix test`
Expected: All PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/klass_hero_web/user_auth.ex lib/klass_hero_web/router.ex
git commit -m "feat: add :staff_provider routing and auth mount hook"
```

---

## Task 13: Staff Registration Changeset

**Files:**
- Modify: `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex`
- Create: `test/klass_hero/accounts/adapters/driven/persistence/schemas/user_staff_registration_test.exs`

- [ ] **Step 1: Write failing test for staff_registration_changeset/2**

Test that the changeset:
- Requires `name` and `email`
- Locks `intended_roles` to `[:staff_provider]` (not user-selectable)
- Does NOT require `provider_subscription_tier`
- Validates email format and uniqueness

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — function undefined.

- [ ] **Step 3: Implement staff_registration_changeset/3**

Follows the same pattern as `registration_changeset/3`. Accepts `opts` for email uniqueness validation (used in tests vs. production).

```elixir
def staff_registration_changeset(user, attrs, opts \\ []) do
  user
  |> cast(attrs, [:name, :email])
  |> validate_required([:name, :email])
  |> put_change(:intended_roles, [:staff_provider])
  |> validate_email(opts)
  |> password_changeset(attrs, opts)
end
```

This reuses the existing private `validate_email/2` (handles format + uniqueness) and `password_changeset/3` (handles hashing + validation). The key difference from `registration_changeset`: `intended_roles` is locked to `[:staff_provider]` via `put_change` (not cast from user input), and `provider_subscription_tier` is not validated.

- [ ] **Step 3b: Modify RegisterUser use case to accept a changeset function option**

In `lib/klass_hero/accounts/application/use_cases/register_user.ex`, update `execute/1` to `execute/2`:
```elixir
def execute(attrs, opts \\ []) do
  changeset_fn = Keyword.get(opts, :changeset_fn, &User.registration_changeset/3)
  # Use changeset_fn instead of hardcoded User.registration_changeset
end
```

Also update `UserRepository.register/2` to accept the changeset function and use it instead of the hardcoded `User.registration_changeset(attrs)`.

- [ ] **Step 3c: Add Accounts.register_staff_user/1 to the Accounts facade**

In `lib/klass_hero/accounts.ex`, add:
```elixir
def register_staff_user(attrs) do
  RegisterUser.execute(attrs, changeset_fn: &User.staff_registration_changeset/3)
end
```

This reuses the same `RegisterUser` use case (which emits `:user_registered` domain event), so `FamilyEventHandler` and `ProviderEventHandler` fire as normal. The latter naturally skips ProviderProfile creation for `[:staff_provider]`.

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Run full test suite**

Run: `mix test`
Expected: All PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex test/
git commit -m "feat: add staff_registration_changeset for staff provider registration"
```

---

## Task 14: Staff Invitation Registration LiveView

**Files:**
- Create: `lib/klass_hero_web/live/user_live/staff_invitation.ex`
- Create: `test/klass_hero_web/live/user_live/staff_invitation_test.exs`

- [ ] **Step 1: Write failing test — valid token renders form**

```elixir
test "renders registration form with pre-filled fields for valid token", %{conn: conn} do
  # Create staff member with token via fixture
  {raw_token, staff} = create_staff_with_invitation()

  {:ok, view, _html} = live(conn, ~p"/users/staff-invitation/#{raw_token}")

  assert has_element?(view, "#staff-registration-form")
  assert has_element?(view, "input[name='user[name]']")
  assert has_element?(view, "input[name='user[email]']")
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — LiveView module doesn't exist.

- [ ] **Step 3: Implement StaffInvitation LiveView — mount**

```elixir
defmodule KlassHeroWeb.UserLive.StaffInvitation do
  use KlassHeroWeb, :live_view

  alias KlassHero.Provider

  @invitation_expiry_days 7

  def mount(%{"token" => raw_token}, _session, socket) do
    with {:ok, decoded} <- Base.url_decode64(raw_token, padding: false),
         token_hash = :crypto.hash(:sha256, decoded),
         {:ok, staff_member} <- Provider.get_staff_member_by_token_hash(token_hash) do
      if invitation_expired?(staff_member) do
        Provider.expire_staff_invitation(staff_member.id)
        {:ok, assign(socket, :error, :expired)}
      else
        form = to_form(%{"name" => StaffMember.full_name(staff_member), "email" => staff_member.email}, as: :user)
        {:ok, assign(socket, staff_member: staff_member, raw_token: raw_token, form: form, error: nil)}
      end
    else
      _ -> {:ok, assign(socket, :error, :invalid)}
    end
  end

  defp invitation_expired?(%{invitation_sent_at: nil}), do: false
  defp invitation_expired?(%{invitation_sent_at: sent_at}) do
    DateTime.diff(DateTime.utc_now(), sent_at, :day) >= @invitation_expiry_days
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Write failing test — expired token shows error**

- [ ] **Step 6: Write failing test — invalid token shows error**

- [ ] **Step 7: Implement render/1 with form and error states**

Build the HEEx template with conditional rendering based on `@error` assign.

- [ ] **Step 8: Write failing test — successful form submission**

Test that submitting the form with valid data:
- Creates a user with `:staff_provider` role
- Emits `:staff_user_registered` event
- Redirects to `/staff/dashboard`

- [ ] **Step 9: Implement handle_event("save", ...)**

On form submit:
1. Call `Accounts.register_staff_user/1` (defined in Task 13 Step 3b — wraps the staff changeset)
2. On success, emit `:staff_user_registered` integration event from within the Accounts facade/use case layer (not from the LiveView — LiveViews are thin driving adapters). Pass `staff_member_id` and `provider_id` through attrs so the use case can include them in the event payload.
3. Log in user via `UserAuth.log_in_user/3` and redirect to `/staff/dashboard`

- [ ] **Step 10: Run all LiveView tests**

Run: `mix test test/klass_hero_web/live/user_live/staff_invitation_test.exs`
Expected: All PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/klass_hero_web/live/user_live/staff_invitation.ex test/klass_hero_web/live/user_live/staff_invitation_test.exs
git commit -m "feat: add staff invitation registration LiveView"
```

---

## Task 15: Staff Dashboard LiveView (Minimal)

**Files:**
- Create: `lib/klass_hero_web/live/staff/staff_dashboard_live.ex`
- Create: `test/klass_hero_web/live/staff/staff_dashboard_live_test.exs`

- [ ] **Step 1: Write failing test — staff dashboard shows business name and programs**

```elixir
test "staff provider sees business name and assigned programs", %{conn: conn} do
  # Create user, provider, staff member linked to user, programs matching tags
  {conn, _user} = register_and_log_in_staff_provider(conn)

  {:ok, view, _html} = live(conn, ~p"/staff/dashboard")

  assert has_element?(view, "#staff-dashboard")
  assert has_element?(view, "#business-name")
  assert has_element?(view, "#assigned-programs")
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — LiveView doesn't exist.

- [ ] **Step 3: Implement StaffDashboardLive**

```elixir
defmodule KlassHeroWeb.StaffDashboardLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Provider
  alias KlassHero.ProgramCatalog

  def mount(_params, _session, socket) do
    staff_member = socket.assigns.current_scope.staff_member

    {:ok, provider} = Provider.get_provider_profile(staff_member.provider_id)

    all_programs = ProgramCatalog.list_programs_for_provider(staff_member.provider_id)

    programs =
      if staff_member.tags == [] do
        all_programs
      else
        Enum.filter(all_programs, fn p -> p.category in staff_member.tags end)
      end

    socket =
      socket
      |> assign(:page_title, "Staff Dashboard")
      |> assign(:provider, provider)
      |> assign(:staff_member, staff_member)
      |> stream(:programs, programs)

    {:ok, socket}
  end
end
```

Build a minimal template showing business name and a stream of program cards.

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Run full test suite**

Run: `mix test`
Expected: All PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero_web/live/staff/staff_dashboard_live.ex test/klass_hero_web/live/staff/staff_dashboard_live_test.exs
git commit -m "feat: add minimal staff dashboard LiveView"
```

---

## Task 16: Provider Team UI — Invitation Status & Resend

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Modify: `lib/klass_hero_web/components/provider_components.ex`
- Modify: `lib/klass_hero_web/presenters/staff_member_presenter.ex`
- Create: `lib/klass_hero/provider/application/use_cases/staff_members/resend_staff_invitation.ex`
- Create: `test/klass_hero/provider/application/use_cases/staff_members/resend_staff_invitation_test.exs`
- Modify: `test/klass_hero_web/live/provider/dashboard_live_test.exs` (or create invitation-specific test file)

- [ ] **Step 1: Write failing test for ResendStaffInvitation use case**

Test that calling resend on a `:failed` or `:expired` staff member:
- Transitions status back to `:pending`
- Generates a new token, clears old hash
- Emits `:staff_member_invited` event

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement ResendStaffInvitation use case**

```elixir
defmodule KlassHero.Provider.Application.UseCases.StaffMembers.ResendStaffInvitation do
  # Fetch staff member, validate transition, generate new token, persist, emit event
end
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Add resend_staff_invitation/1 to Provider facade**

- [ ] **Step 6: Update StaffMemberPresenter to include invitation_status**

Add `invitation_status` and `invitation_status_label` to the presenter output.

- [ ] **Step 7: Update provider_components.ex — add invitation status badge**

Show status badge (pending/sent/failed/expired/accepted) next to each staff member in the team list.

- [ ] **Step 8: Update provider_components.ex — add resend button**

Show "Resend Invite" button for staff members with `:failed` or `:expired` status.

- [ ] **Step 9: Handle "resend_invitation" event in dashboard_live.ex**

```elixir
def handle_event("resend_invitation", %{"id" => staff_member_id}, socket) do
  case Provider.resend_staff_invitation(staff_member_id) do
    {:ok, updated} -> # update stream
    {:error, _} -> # flash error
  end
end
```

- [ ] **Step 10: Write LiveView test for resend button**

- [ ] **Step 11: Run all tests**

Run: `mix test`
Expected: All PASS.

- [ ] **Step 12: Commit**

```bash
git add lib/klass_hero/provider/application/use_cases/staff_members/resend_staff_invitation.ex lib/klass_hero_web/ test/
git commit -m "feat: add invitation status display and resend flow to team UI"
```

---

## Task 17: Integration Tests — Full Saga Flows

**Files:**
- Create: `test/klass_hero/integration/staff_invitation_saga_test.exs`

- [ ] **Step 1: Write integration test — full saga, new user**

End-to-end test:
1. Create staff member with email
2. Verify `:staff_member_invited` event emitted
3. Simulate handler processing (or call handler directly)
4. Verify invitation email sent
5. Verify status transitions: `:pending` → `:sent`
6. Simulate registration via invitation
7. Verify status transitions: `:sent` → `:accepted`
8. Verify `user_id` linked
9. Verify no ProviderProfile created for new user

- [ ] **Step 2: Write integration test — full saga, existing user**

1. Create user first
2. Create staff member with that user's email
3. Verify notification email sent (not invitation)
4. Verify status jumps straight to `:accepted`
5. Verify `user_id` linked

- [ ] **Step 3: Write integration test — compensation (email failure)**

1. Create staff member
2. Simulate email delivery failure
3. Verify `:staff_invitation_failed` emitted
4. Verify status transitions to `:failed`
5. Resend
6. Verify saga restarts from `:pending`

- [ ] **Step 4: Run all integration tests**

Run: `mix test test/klass_hero/integration/staff_invitation_saga_test.exs`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add test/klass_hero/integration/staff_invitation_saga_test.exs
git commit -m "test: add full saga integration tests for staff invitation flow"
```

---

## Task 18: Final — Precommit & Cleanup

**Files:**
- No new files — validation pass

- [ ] **Step 1: Run mix precommit**

Run: `mix precommit`
Expected: Compiles with zero warnings, format check passes, all tests pass.

- [ ] **Step 2: Fix any warnings or formatting issues**

- [ ] **Step 3: Verify compilation with warnings-as-errors**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation.

- [ ] **Step 4: Run full test suite one final time**

Run: `mix test`
Expected: All tests PASS.

- [ ] **Step 5: Final commit if any cleanup was needed**

```bash
git add -A
git commit -m "chore: final cleanup for staff invitation saga"
```

- [ ] **Step 6: Push to remote**

```bash
git pull --rebase
git push
```
