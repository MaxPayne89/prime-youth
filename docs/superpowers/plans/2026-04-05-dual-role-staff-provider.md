# Dual-Role Staff + Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow staff members to opt-in as independent providers during invitation registration, with both dashboards accessible via cross-navigation.

**Architecture:** Extends the existing staff invitation flow with an opt-in checkbox. The `:staff_user_registered` integration event carries a `create_provider_profile` flag. The Provider context's `StaffInvitationStatusHandler` creates a starter provider profile when flagged. Router precedence is swapped so dual-role users land on the provider dashboard. Cross-nav links connect both dashboards.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Ecto, PostgreSQL, Oban (integration events)

**Tidewave MCP:** Use throughout for docs lookup (`get_docs`), code evaluation (`project_eval`), schema inspection (`get_ecto_schemas`), SQL verification (`execute_sql_query`), and log checking (`get_logs`). Prefer Tidewave over bash for all Phoenix/Elixir introspection.

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `priv/repo/migrations/*_add_originated_from_to_providers.exs` | Create | Migration: add `originated_from` column |
| `lib/klass_hero/provider/domain/models/provider_profile.ex` | Modify | Add `originated_from` field to domain struct |
| `lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema.ex` | Modify | Add `originated_from` to Ecto schema + changeset |
| `lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper.ex` | Modify | Map `originated_from` between string/atom |
| `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex` | Modify | Support dual roles in `staff_registration_changeset` |
| `lib/klass_hero/accounts.ex` | Modify | Extend `emit_staff_user_registered` with opts map |
| `lib/klass_hero/provider/adapters/driving/events/staff_invitation_status_handler.ex` | Modify | Create provider profile when `create_provider_profile` flag set |
| `lib/klass_hero_web/live/user_live/staff_invitation.ex` | Modify | Add opt-in checkbox, pass flag to event |
| `lib/klass_hero_web/user_auth.ex` | Modify | Swap precedence: provider > staff |
| `lib/klass_hero_web/live/provider/dashboard_live.ex` | Modify | Add cross-nav link to staff dashboard |
| `lib/klass_hero_web/live/staff/staff_dashboard_live.ex` | Modify | Add cross-nav link to provider dashboard |

---

### Task 1: Migration — add `originated_from` to provider profiles

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_originated_from_to_providers.exs`

- [ ] **Step 1: Generate the migration**

```bash
mix ecto.gen.migration add_originated_from_to_providers
```

- [ ] **Step 2: Write the migration**

Open the generated file and write:

```elixir
defmodule KlassHero.Repo.Migrations.AddOriginatedFromToProviders do
  use Ecto.Migration

  def change do
    alter table(:providers) do
      add :originated_from, :string, default: "direct", null: false
    end
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
mix ecto.migrate
```

- [ ] **Step 4: Verify with Tidewave MCP**

Use `execute_sql_query` to confirm the column exists:

```sql
SELECT column_name, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'providers' AND column_name = 'originated_from';
```

Expected: column exists with default `'direct'`, not nullable.

Also verify existing records were backfilled:

```sql
SELECT originated_from, count(*) FROM providers GROUP BY originated_from;
```

Expected: all existing records show `'direct'`.

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations/*_add_originated_from_to_providers.exs
git commit -m "feat: add originated_from column to providers table"
```

---

### Task 2: Provider profile domain model — add `originated_from`

**Files:**
- Modify: `lib/klass_hero/provider/domain/models/provider_profile.ex`
- Test: `test/klass_hero/provider/domain/models/provider_profile_test.exs`

- [ ] **Step 1: Write the failing test**

Use Tidewave `get_docs` to check `ProviderProfile.new/1` behavior, then add tests:

```elixir
# In provider_profile_test.exs, add to the existing describe block for new/1:

describe "originated_from field" do
  test "defaults to :direct when not provided" do
    attrs = %{
      id: Ecto.UUID.generate(),
      identity_id: Ecto.UUID.generate(),
      business_name: "Test Business"
    }

    assert {:ok, profile} = ProviderProfile.new(attrs)
    assert profile.originated_from == :direct
  end

  test "accepts :staff_invite as originated_from" do
    attrs = %{
      id: Ecto.UUID.generate(),
      identity_id: Ecto.UUID.generate(),
      business_name: "Test Business",
      originated_from: :staff_invite
    }

    assert {:ok, profile} = ProviderProfile.new(attrs)
    assert profile.originated_from == :staff_invite
  end

  test "rejects invalid originated_from values" do
    attrs = %{
      id: Ecto.UUID.generate(),
      identity_id: Ecto.UUID.generate(),
      business_name: "Test Business",
      originated_from: :unknown
    }

    assert {:error, errors} = ProviderProfile.new(attrs)
    assert "originated_from must be :direct or :staff_invite" in errors
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/provider/domain/models/provider_profile_test.exs --max-failures 1
```

Expected: FAIL — `originated_from` field doesn't exist on struct.

- [ ] **Step 3: Implement — add field to domain model**

In `lib/klass_hero/provider/domain/models/provider_profile.ex`:

Add `:originated_from` to the struct (after `:subscription_tier` on line 30):

```elixir
defstruct [
    :id,
    :identity_id,
    :business_name,
    :description,
    :phone,
    :website,
    :address,
    :logo_url,
    :verified,
    :verified_at,
    :verified_by_id,
    :categories,
    :subscription_tier,
    :originated_from,
    :inserted_at,
    :updated_at
  ]
```

Add to the type spec (after `subscription_tier` line):

```elixir
originated_from: :direct | :staff_invite | nil,
```

Add default in `apply_defaults/1` (after line 85):

```elixir
|> Map.put_new(:originated_from, :direct)
```

Add validation call in `validate/1` (after line 164):

```elixir
|> validate_originated_from(provider_profile.originated_from)
```

Add the validation function (after `validate_subscription_tier` at end of module):

```elixir
@valid_originated_from [:direct, :staff_invite]

defp validate_originated_from(errors, from) when from in @valid_originated_from, do: errors

defp validate_originated_from(errors, _),
  do: ["originated_from must be :direct or :staff_invite" | errors]
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/klass_hero/provider/domain/models/provider_profile_test.exs
```

Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/provider/domain/models/provider_profile.ex test/klass_hero/provider/domain/models/provider_profile_test.exs
git commit -m "feat: add originated_from field to ProviderProfile domain model"
```

---

### Task 3: Provider profile schema — add `originated_from`

**Files:**
- Modify: `lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema.ex`
- Test: `test/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# Add to the existing schema test file:

describe "originated_from field" do
  test "changeset accepts originated_from" do
    attrs = %{
      identity_id: Ecto.UUID.generate(),
      business_name: "Test Biz",
      originated_from: "staff_invite"
    }

    changeset = ProviderProfileSchema.changeset(%ProviderProfileSchema{}, attrs)
    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :originated_from) == "staff_invite"
  end

  test "changeset validates originated_from values" do
    attrs = %{
      identity_id: Ecto.UUID.generate(),
      business_name: "Test Biz",
      originated_from: "invalid"
    }

    changeset = ProviderProfileSchema.changeset(%ProviderProfileSchema{}, attrs)
    refute changeset.valid?
    assert {"is not a valid origin", _} = changeset.errors[:originated_from]
  end

  test "defaults to 'direct' in schema" do
    schema = %ProviderProfileSchema{}
    assert schema.originated_from == "direct"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema_test.exs --max-failures 1
```

Expected: FAIL — field not on schema.

- [ ] **Step 3: Implement — add field to schema**

In `lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema.ex`:

Add to schema block (after `subscription_tier` line 35):

```elixir
field :originated_from, :string, default: "direct"
```

Add `:originated_from` to the cast list in `changeset/2` (line 62-75), and add validation:

```elixir
|> validate_inclusion(:originated_from, ~w(direct staff_invite),
  message: "is not a valid origin"
)
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema_test.exs
```

Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema.ex test/klass_hero/provider/adapters/driven/persistence/schemas/provider_profile_schema_test.exs
git commit -m "feat: add originated_from field to ProviderProfileSchema"
```

---

### Task 4: Provider profile mapper — map `originated_from`

**Files:**
- Modify: `lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper.ex`
- Test: `test/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# Add to existing mapper test file:

describe "originated_from mapping" do
  test "to_domain/1 converts string to atom" do
    schema = %ProviderProfileSchema{
      id: Ecto.UUID.generate(),
      identity_id: Ecto.UUID.generate(),
      business_name: "Test",
      originated_from: "staff_invite",
      subscription_tier: "starter",
      categories: [],
      verified: false
    }

    domain = ProviderProfileMapper.to_domain(schema)
    assert domain.originated_from == :staff_invite
  end

  test "to_domain/1 defaults originated_from to :direct" do
    schema = %ProviderProfileSchema{
      id: Ecto.UUID.generate(),
      identity_id: Ecto.UUID.generate(),
      business_name: "Test",
      originated_from: "direct",
      subscription_tier: "starter",
      categories: [],
      verified: false
    }

    domain = ProviderProfileMapper.to_domain(schema)
    assert domain.originated_from == :direct
  end

  test "to_schema/1 converts atom to string" do
    domain = %ProviderProfile{
      id: Ecto.UUID.generate(),
      identity_id: Ecto.UUID.generate(),
      business_name: "Test",
      originated_from: :staff_invite,
      subscription_tier: :starter
    }

    attrs = ProviderProfileMapper.to_schema(domain)
    assert attrs.originated_from == "staff_invite"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper_test.exs --max-failures 1
```

Expected: FAIL — `originated_from` not mapped.

- [ ] **Step 3: Implement — add mapping**

In `lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper.ex`:

In `to_domain/1` (after `subscription_tier` line 48), add:

```elixir
originated_from: string_to_origin(schema.originated_from),
```

In `to_schema/1` (after `subscription_tier` line 74), add:

```elixir
originated_from: origin_to_string(provider_profile.originated_from),
```

Add private helpers at end of module:

```elixir
defp string_to_origin("staff_invite"), do: :staff_invite
defp string_to_origin(_), do: :direct

defp origin_to_string(:staff_invite), do: "staff_invite"
defp origin_to_string(_), do: "direct"
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper_test.exs
```

Expected: ALL PASS.

- [ ] **Step 5: Verify round-trip with Tidewave MCP**

Use `project_eval` to test a full round-trip:

```elixir
alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderProfileMapper
alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema

schema = %ProviderProfileSchema{
  id: Ecto.UUID.generate(),
  identity_id: Ecto.UUID.generate(),
  business_name: "Test",
  originated_from: "staff_invite",
  subscription_tier: "starter",
  categories: [],
  verified: false
}

domain = ProviderProfileMapper.to_domain(schema)
IO.inspect(domain.originated_from, label: "domain originated_from")

attrs = ProviderProfileMapper.to_schema(domain)
IO.inspect(attrs.originated_from, label: "schema originated_from")
```

Expected: `:staff_invite` → `"staff_invite"` round-trip.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper.ex test/klass_hero/provider/adapters/driven/persistence/mappers/provider_profile_mapper_test.exs
git commit -m "feat: map originated_from in ProviderProfileMapper"
```

---

### Task 5: Staff registration changeset — dual-role support

**Files:**
- Modify: `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex`
- Test: `test/klass_hero/accounts/adapters/driven/persistence/schemas/user_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# Add to the existing user schema test file:

describe "staff_registration_changeset/3 dual-role support" do
  test "sets [:staff_provider] when also_provider is not set" do
    attrs = %{"name" => "Test", "email" => "test@example.com", "password" => "long_password123"}

    changeset = User.staff_registration_changeset(%User{}, attrs, hash_password: false)
    assert Ecto.Changeset.get_field(changeset, :intended_roles) == [:staff_provider]
  end

  test "sets [:staff_provider, :provider] when also_provider is 'true'" do
    attrs = %{
      "name" => "Test",
      "email" => "test@example.com",
      "password" => "long_password123",
      "also_provider" => "true"
    }

    changeset = User.staff_registration_changeset(%User{}, attrs, hash_password: false)
    assert Ecto.Changeset.get_field(changeset, :intended_roles) == [:staff_provider, :provider]
  end

  test "sets [:staff_provider] when also_provider is 'false'" do
    attrs = %{
      "name" => "Test",
      "email" => "test@example.com",
      "password" => "long_password123",
      "also_provider" => "false"
    }

    changeset = User.staff_registration_changeset(%User{}, attrs, hash_password: false)
    assert Ecto.Changeset.get_field(changeset, :intended_roles) == [:staff_provider]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/accounts/adapters/driven/persistence/schemas/user_test.exs --max-failures 1
```

Expected: FAIL — the dual-role test fails because changeset always sets `[:staff_provider]`.

- [ ] **Step 3: Implement — modify staff_registration_changeset**

In `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex`, replace `staff_registration_changeset/3` (lines 101-109):

```elixir
def staff_registration_changeset(user, attrs, opts \\ []) do
    also_provider = Map.get(attrs, "also_provider") == "true"
    roles = if also_provider, do: [:staff_provider, :provider], else: [:staff_provider]

    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_length(:name, min: 2, max: 100)
    |> put_change(:intended_roles, roles)
    |> validate_email(opts)
    |> password_changeset(attrs, opts)
  end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/klass_hero/accounts/adapters/driven/persistence/schemas/user_test.exs
```

Expected: ALL PASS.

- [ ] **Step 5: Verify with Tidewave MCP**

Use `project_eval` to confirm changeset behavior:

```elixir
alias KlassHero.Accounts.User

attrs = %{"name" => "Shane", "email" => "shane@example.com", "password" => "long_password123", "also_provider" => "true"}
changeset = User.staff_registration_changeset(%User{}, attrs, hash_password: false)
IO.inspect(Ecto.Changeset.get_field(changeset, :intended_roles))
```

Expected: `[:staff_provider, :provider]`

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex test/klass_hero/accounts/adapters/driven/persistence/schemas/user_test.exs
git commit -m "feat: support dual-role in staff registration changeset"
```

---

### Task 6: Accounts API — extend `emit_staff_user_registered` payload

**Files:**
- Modify: `lib/klass_hero/accounts.ex`
- Test: `test/klass_hero/accounts_test.exs`

- [ ] **Step 1: Write the failing test**

Use Tidewave `get_docs` to check `IntegrationEventPublishing.publish_critical/3` signature.

```elixir
# Add to existing accounts_test.exs:

describe "emit_staff_user_registered/4" do
  test "includes create_provider_profile in event payload when passed" do
    # We can test this by capturing the published event.
    # Use the test event subscriber pattern from the project.
    user = KlassHero.AccountsFixtures.user_fixture(intended_roles: [:staff_provider])
    staff_member_id = Ecto.UUID.generate()
    provider_id = Ecto.UUID.generate()

    assert :ok =
             Accounts.emit_staff_user_registered(user.id, staff_member_id, provider_id, %{
               create_provider_profile: true
             })
  end

  test "works without opts (backwards compatible)" do
    user = KlassHero.AccountsFixtures.user_fixture(intended_roles: [:staff_provider])
    staff_member_id = Ecto.UUID.generate()
    provider_id = Ecto.UUID.generate()

    assert :ok = Accounts.emit_staff_user_registered(user.id, staff_member_id, provider_id)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/accounts_test.exs --max-failures 1
```

Expected: FAIL — `emit_staff_user_registered/4` doesn't exist (only arity 3).

- [ ] **Step 3: Implement — add optional opts parameter**

In `lib/klass_hero/accounts.ex`, modify `emit_staff_user_registered` (lines 116-129):

```elixir
  @spec emit_staff_user_registered(String.t(), String.t(), String.t(), map()) ::
          :ok | {:error, term()}
  def emit_staff_user_registered(user_id, staff_member_id, provider_id, opts \\ %{})
      when is_binary(user_id) and is_binary(staff_member_id) and is_binary(provider_id) do
    payload =
      %{staff_member_id: staff_member_id, provider_id: provider_id}
      |> Map.merge(opts)

    user_id
    |> AccountsIntegrationEvents.staff_user_registered(payload)
    |> IntegrationEventPublishing.publish_critical("staff_user_registered",
      user_id: user_id,
      staff_member_id: staff_member_id
    )
  end
```

Update the `@doc` to mention the new parameter:

```elixir
  @doc """
  Emits a `staff_user_registered` integration event.

  Called by the invitation registration LiveView after a successful
  `register_staff_user/1`. The LiveView knows the staff context
  (staff_member_id, provider_id) that the use case layer does not.

  ## Options (4th argument, optional map)

  - `create_provider_profile: true` — signals the Provider context to
    create a starter provider profile for this user.

  Returns `:ok` on success or `{:error, reason}` on publish failure.
  """
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/klass_hero/accounts_test.exs
```

Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/accounts.ex test/klass_hero/accounts_test.exs
git commit -m "feat: extend emit_staff_user_registered with optional payload"
```

---

### Task 7: StaffInvitationStatusHandler — create provider profile on flag

**Files:**
- Modify: `lib/klass_hero/provider/adapters/driving/events/staff_invitation_status_handler.ex`
- Test: `test/klass_hero/provider/adapters/driving/events/staff_invitation_status_handler_test.exs`

- [ ] **Step 1: Write the failing test**

Use Tidewave `get_docs` to check `CreateProviderProfile.execute/1` signature.

```elixir
# Add to existing handler test file (or create if it doesn't exist):

describe "handle_event/1 staff_user_registered with create_provider_profile flag" do
  test "creates a provider profile when create_provider_profile is true" do
    # Setup: create a user, provider, and staff member with sent invitation
    user = KlassHero.AccountsFixtures.user_fixture(intended_roles: [:staff_provider, :provider])
    provider = KlassHero.ProviderFixtures.provider_profile_fixture()

    staff =
      KlassHero.ProviderFixtures.staff_member_fixture(
        provider_id: provider.id,
        email: "staff@test.com",
        first_name: "Test",
        last_name: "Staff",
        invitation_status: :sent,
        invitation_token_hash: :crypto.hash(:sha256, "test-token"),
        invitation_sent_at: DateTime.utc_now()
      )

    event =
      KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents.staff_user_registered(
        user.id,
        %{
          staff_member_id: staff.id,
          provider_id: provider.id,
          create_provider_profile: true,
          user_name: user.name
        }
      )

    assert :ok = StaffInvitationStatusHandler.handle_event(event)

    # Verify provider profile was created
    assert {:ok, created_profile} = KlassHero.Provider.get_provider_by_identity(user.id)
    assert created_profile.originated_from == :staff_invite
    assert created_profile.business_name == user.name
  end

  test "does NOT create a provider profile when flag is absent" do
    user = KlassHero.AccountsFixtures.user_fixture(intended_roles: [:staff_provider])
    provider = KlassHero.ProviderFixtures.provider_profile_fixture()

    staff =
      KlassHero.ProviderFixtures.staff_member_fixture(
        provider_id: provider.id,
        email: "staff2@test.com",
        first_name: "Test",
        last_name: "Staff",
        invitation_status: :sent,
        invitation_token_hash: :crypto.hash(:sha256, "test-token-2"),
        invitation_sent_at: DateTime.utc_now()
      )

    event =
      KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents.staff_user_registered(
        user.id,
        %{
          staff_member_id: staff.id,
          provider_id: provider.id
        }
      )

    assert :ok = StaffInvitationStatusHandler.handle_event(event)

    # Verify NO provider profile was created
    assert {:error, :not_found} = KlassHero.Provider.get_provider_by_identity(user.id)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero/provider/adapters/driving/events/staff_invitation_status_handler_test.exs --max-failures 1
```

Expected: FAIL — handler doesn't create provider profiles.

- [ ] **Step 3: Implement — extend handler**

In `lib/klass_hero/provider/adapters/driving/events/staff_invitation_status_handler.ex`:

Add alias at top (after existing aliases):

```elixir
alias KlassHero.Provider.Application.UseCases.Providers.CreateProviderProfile
```

Modify the `handle_event` for `:staff_user_registered` (lines 42-56):

```elixir
  def handle_event(%IntegrationEvent{event_type: :staff_user_registered, payload: payload}) do
    payload = MapperHelpers.normalize_keys(payload)

    case Map.fetch(payload, :user_id) do
      {:ok, user_id} ->
        result =
          transition_and_persist(payload, :accepted, fn transitioned ->
            %{transitioned | user_id: user_id}
          end)

        if result == :ok and payload[:create_provider_profile] do
          maybe_create_provider_profile(user_id, payload)
        end

        result

      :error ->
        Logger.error("[StaffInvitationStatusHandler] Missing :user_id in staff_user_registered payload")
        {:error, :invalid_payload}
    end
  end
```

Add the private helper at end of module (before the last `end`):

```elixir
  defp maybe_create_provider_profile(user_id, payload) do
    business_name = payload[:user_name] || "My Business"

    case CreateProviderProfile.execute(%{
           identity_id: user_id,
           business_name: business_name,
           originated_from: :staff_invite
         }) do
      {:ok, profile} ->
        Logger.info("[StaffInvitationStatusHandler] Created provider profile for staff user",
          user_id: user_id,
          provider_id: profile.id
        )

      {:error, :duplicate_identity} ->
        Logger.info("[StaffInvitationStatusHandler] Provider profile already exists",
          user_id: user_id
        )

      {:error, reason} ->
        Logger.error("[StaffInvitationStatusHandler] Failed to create provider profile",
          user_id: user_id,
          reason: inspect(reason)
        )
    end
  end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/klass_hero/provider/adapters/driving/events/staff_invitation_status_handler_test.exs
```

Expected: ALL PASS.

- [ ] **Step 5: Verify with Tidewave MCP**

Use `get_logs` to check for any warnings during the test run. Use `project_eval` to confirm `CreateProviderProfile.execute/1` accepts `originated_from`:

```elixir
alias KlassHero.Provider.Application.UseCases.Providers.CreateProviderProfile
# Inspect the module's function info
CreateProviderProfile.__info__(:functions)
```

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/provider/adapters/driving/events/staff_invitation_status_handler.ex test/klass_hero/provider/adapters/driving/events/staff_invitation_status_handler_test.exs
git commit -m "feat: create provider profile on staff registration when opted in"
```

---

### Task 8: Staff invitation LiveView — add opt-in checkbox

**Files:**
- Modify: `lib/klass_hero_web/live/user_live/staff_invitation.ex`
- Test: `test/klass_hero_web/live/user_live/staff_invitation_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# Create or add to test/klass_hero_web/live/user_live/staff_invitation_test.exs:

defmodule KlassHeroWeb.UserLive.StaffInvitationTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.Provider
  alias KlassHero.ProviderFixtures

  setup do
    provider = ProviderFixtures.provider_profile_fixture()

    {raw_token, token_hash} =
      KlassHero.Provider.Domain.Models.StaffMember.generate_invitation_token()

    staff =
      ProviderFixtures.staff_member_fixture(
        provider_id: provider.id,
        email: "invite@test.com",
        first_name: "Test",
        last_name: "Staff",
        invitation_status: :sent,
        invitation_token_hash: token_hash,
        invitation_sent_at: DateTime.utc_now()
      )

    encoded_token = Base.url_encode64(raw_token, padding: false)
    %{staff: staff, provider: provider, token: encoded_token}
  end

  describe "also_provider checkbox" do
    test "renders the opt-in checkbox", %{conn: conn, token: token} do
      {:ok, view, _html} = live(conn, ~p"/users/staff-invitation/#{token}")
      assert has_element?(view, "#staff-registration-form input[name='user[also_provider]']")
    end

    test "submitting with checkbox checked passes also_provider to registration", %{
      conn: conn,
      token: token
    } do
      {:ok, view, _html} = live(conn, ~p"/users/staff-invitation/#{token}")

      view
      |> form("#staff-registration-form", %{
        "user" => %{
          "name" => "Test Staff",
          "email" => "invite@test.com",
          "password" => "long_password123",
          "also_provider" => "true"
        }
      })
      |> render_submit()

      flash = assert_redirect(view, ~p"/users/log-in")
      assert flash["info"] =~ "Account created"
    end

    test "submitting without checkbox works normally", %{conn: conn, token: token} do
      {:ok, view, _html} = live(conn, ~p"/users/staff-invitation/#{token}")

      view
      |> form("#staff-registration-form", %{
        "user" => %{
          "name" => "Test Staff",
          "email" => "invite@test.com",
          "password" => "long_password123"
        }
      })
      |> render_submit()

      flash = assert_redirect(view, ~p"/users/log-in")
      assert flash["info"] =~ "Account created"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero_web/live/user_live/staff_invitation_test.exs --max-failures 1
```

Expected: FAIL — checkbox element not found.

- [ ] **Step 3: Implement — add checkbox and pass flag**

In `lib/klass_hero_web/live/user_live/staff_invitation.ex`:

Add the checkbox to the form (after the password input, before the button — around line 71):

```heex
              <label class="flex items-center gap-2 mt-4 cursor-pointer">
                <input
                  type="checkbox"
                  name="user[also_provider]"
                  value="true"
                  class="rounded border-zinc-300 text-brand focus:ring-brand"
                />
                <span class={Theme.typography(:body_small)}>
                  {gettext("I also want to offer my own programs")}
                </span>
              </label>
```

Add `alias KlassHeroWeb.Theme` to the alias section at top of module (after existing aliases).

Modify the `handle_event("save", ...)` (line 115) to pass `also_provider` flag to the event:

```elixir
  def handle_event("save", %{"user" => user_params}, socket) do
    staff = socket.assigns.staff_member
    also_provider = Map.get(user_params, "also_provider") == "true"
    params = Map.put(user_params, "email", staff.email)

    case Accounts.register_staff_user(params) do
      {:ok, user} ->
        event_opts =
          if also_provider,
            do: %{create_provider_profile: true, user_name: user.name},
            else: %{}

        case Accounts.emit_staff_user_registered(user.id, staff.id, staff.provider_id, event_opts) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error("[StaffInvitation] Failed to emit staff_user_registered",
              user_id: user.id,
              staff_member_id: staff.id,
              reason: inspect(reason)
            )
        end

        case Accounts.deliver_login_instructions(user, &url(~p"/users/log-in/#{&1}")) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.error("[StaffInvitation] Failed to deliver login instructions",
              user_id: user.id,
              reason: inspect(reason)
            )
        end

        {:noreply,
         socket
         |> put_flash(:info, gettext("Account created! Check your email to confirm and log in."))
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/klass_hero_web/live/user_live/staff_invitation_test.exs
```

Expected: ALL PASS.

- [ ] **Step 5: Verify with Tidewave MCP**

Use `get_logs` after running tests to check for unexpected errors. Use `project_eval` to verify the form renders correctly if server is running.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero_web/live/user_live/staff_invitation.ex test/klass_hero_web/live/user_live/staff_invitation_test.exs
git commit -m "feat: add opt-in provider checkbox to staff invitation form"
```

---

### Task 9: Router precedence swap

**Files:**
- Modify: `lib/klass_hero_web/user_auth.ex`
- Test: `test/klass_hero_web/user_auth_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# Add to existing user_auth_test.exs:

describe "signed_in_path/1 dual-role precedence" do
  test "provider takes precedence over staff for dual-role users" do
    user = %KlassHero.Accounts.User{intended_roles: [:staff_provider, :provider]}
    assert KlassHeroWeb.UserAuth.signed_in_path(user) == ~p"/provider/dashboard"
  end

  test "staff-only users still go to staff dashboard" do
    user = %KlassHero.Accounts.User{intended_roles: [:staff_provider]}
    assert KlassHeroWeb.UserAuth.signed_in_path(user) == ~p"/staff/dashboard"
  end

  test "provider-only users go to provider dashboard" do
    user = %KlassHero.Accounts.User{intended_roles: [:provider]}
    assert KlassHeroWeb.UserAuth.signed_in_path(user) == ~p"/provider/dashboard"
  end
end

describe "dashboard_path/1 dual-role precedence" do
  test "provider takes precedence over staff for dual-role users" do
    user = %KlassHero.Accounts.User{intended_roles: [:staff_provider, :provider]}
    assert KlassHeroWeb.UserAuth.dashboard_path(user) == ~p"/provider/dashboard"
  end

  test "staff-only users still go to staff dashboard" do
    user = %KlassHero.Accounts.User{intended_roles: [:staff_provider]}
    assert KlassHeroWeb.UserAuth.dashboard_path(user) == ~p"/staff/dashboard"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mix test test/klass_hero_web/user_auth_test.exs --max-failures 1
```

Expected: FAIL — dual-role user gets `/staff/dashboard` because staff currently takes precedence.

- [ ] **Step 3: Implement — swap precedence in all three functions**

In `lib/klass_hero_web/user_auth.ex`:

**`signed_in_path/1`** (lines 388-394) — swap order:

```elixir
  def signed_in_path(%Accounts.User{intended_roles: roles}) do
    cond do
      :provider in roles -> ~p"/provider/dashboard"
      :staff_provider in roles -> ~p"/staff/dashboard"
      true -> ~p"/users/settings"
    end
  end
```

**`dashboard_path/1`** (lines 399-405) — swap order:

```elixir
  def dashboard_path(%Accounts.User{intended_roles: roles}) do
    cond do
      :provider in roles -> ~p"/provider/dashboard"
      :staff_provider in roles -> ~p"/staff/dashboard"
      true -> ~p"/dashboard"
    end
  end
```

**`redirect_provider_or_staff_from_parent_routes`** (lines 329-338) — swap order:

```elixir
      cond do
        Scope.provider?(scope) ->
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/provider/dashboard")}

        Scope.staff_provider?(scope) ->
          {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/staff/dashboard")}

        true ->
          {:cont, socket}
      end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mix test test/klass_hero_web/user_auth_test.exs
```

Expected: ALL PASS.

- [ ] **Step 5: Run full test suite to check for regressions**

```bash
mix test
```

Expected: ALL PASS. No existing tests should break since there are no dual-role users in the existing test data.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero_web/user_auth.ex test/klass_hero_web/user_auth_test.exs
git commit -m "feat: swap router precedence so provider takes priority over staff"
```

---

### Task 10: Cross-navigation UI on both dashboards

**Files:**
- Modify: `lib/klass_hero_web/live/staff/staff_dashboard_live.ex`
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Test: `test/klass_hero_web/live/staff/staff_dashboard_live_test.exs`
- Test: `test/klass_hero_web/live/provider/dashboard_live_test.exs`

- [ ] **Step 1: Write the failing tests**

**Staff dashboard test** — add to existing test file:

```elixir
describe "cross-navigation for dual-role users" do
  setup %{conn: conn} do
    # Create a dual-role user with both staff member and provider profile
    user =
      KlassHero.AccountsFixtures.user_fixture(intended_roles: [:staff_provider, :provider])

    provider = KlassHero.ProviderFixtures.provider_profile_fixture(identity_id: user.id)

    staff =
      KlassHero.ProviderFixtures.staff_member_fixture(
        provider_id: provider.id,
        user_id: user.id,
        invitation_status: :accepted
      )

    conn = log_in_user(conn, user)
    %{conn: conn, user: user, provider: provider, staff: staff}
  end

  test "shows link to provider dashboard for dual-role users", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/staff/dashboard")
    assert has_element?(view, "#cross-nav-provider-link")
  end
end

describe "cross-navigation for staff-only users" do
  setup %{conn: conn} do
    user = KlassHero.AccountsFixtures.user_fixture(intended_roles: [:staff_provider])
    provider = KlassHero.ProviderFixtures.provider_profile_fixture()

    staff =
      KlassHero.ProviderFixtures.staff_member_fixture(
        provider_id: provider.id,
        user_id: user.id,
        invitation_status: :accepted
      )

    conn = log_in_user(conn, user)
    %{conn: conn, user: user, staff: staff}
  end

  test "does NOT show link to provider dashboard for staff-only users", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/staff/dashboard")
    refute has_element?(view, "#cross-nav-provider-link")
  end
end
```

**Provider dashboard test** — add to existing test file:

```elixir
describe "cross-navigation for dual-role users" do
  setup %{conn: conn} do
    user =
      KlassHero.AccountsFixtures.user_fixture(intended_roles: [:staff_provider, :provider])

    provider = KlassHero.ProviderFixtures.provider_profile_fixture(identity_id: user.id)

    staff =
      KlassHero.ProviderFixtures.staff_member_fixture(
        provider_id: provider.id,
        user_id: user.id,
        invitation_status: :accepted
      )

    conn = log_in_user(conn, user)
    %{conn: conn, user: user, provider: provider, staff: staff}
  end

  test "shows link to staff dashboard for dual-role users", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard")
    assert has_element?(view, "#cross-nav-staff-link")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
mix test test/klass_hero_web/live/staff/staff_dashboard_live_test.exs test/klass_hero_web/live/provider/dashboard_live_test.exs --max-failures 1
```

Expected: FAIL — cross-nav elements don't exist.

- [ ] **Step 3: Implement — add cross-nav to staff dashboard**

In `lib/klass_hero_web/live/staff/staff_dashboard_live.ex`, add a helper function and insert the link in the render function.

Add a private helper to check for dual roles:

```elixir
defp dual_role?(scope) do
  scope.provider != nil and scope.staff_member != nil
end
```

In `mount/3`, add the assign (after existing assigns):

```elixir
|> assign(:dual_role?, dual_role?(socket.assigns.current_scope))
```

In the `render/1` template, add the cross-nav link right after the welcome paragraph (after line 83):

```heex
        <.link
          :if={@dual_role?}
          id="cross-nav-provider-link"
          navigate={~p"/provider/dashboard"}
          class="inline-flex items-center gap-1 text-sm text-brand hover:text-brand/80 mt-2"
        >
          {gettext("Manage your business")} →
        </.link>
```

- [ ] **Step 4: Implement — add cross-nav to provider dashboard**

In `lib/klass_hero_web/live/provider/dashboard_live.ex`:

Add a helper:

```elixir
defp dual_role?(scope) do
  scope.provider != nil and scope.staff_member != nil
end
```

In `mount/3`, add the assign (within the provider_profile branch):

```elixir
|> assign(:dual_role?, dual_role?(socket.assigns.current_scope))
```

In the render template, add the cross-nav link in an appropriate location near the top of the dashboard (e.g., in the header area):

```heex
        <.link
          :if={@dual_role?}
          id="cross-nav-staff-link"
          navigate={~p"/staff/dashboard"}
          class="inline-flex items-center gap-1 text-sm text-brand hover:text-brand/80"
        >
          {gettext("View your assignments")} →
        </.link>
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
mix test test/klass_hero_web/live/staff/staff_dashboard_live_test.exs test/klass_hero_web/live/provider/dashboard_live_test.exs
```

Expected: ALL PASS.

- [ ] **Step 6: Run full test suite**

```bash
mix test
```

Expected: ALL PASS.

- [ ] **Step 7: Verify with Tidewave MCP**

If Phoenix server is running, use `project_eval` to check a dual-role scope:

```elixir
alias KlassHero.Accounts.Scope
# Check that a scope with both provider and staff_member is recognized
scope = %Scope{
  provider: %{id: "test"},
  staff_member: %{id: "test"},
  roles: [:provider, :staff_provider]
}
IO.inspect(scope.provider != nil and scope.staff_member != nil, label: "dual_role?")
```

- [ ] **Step 8: Commit**

```bash
git add lib/klass_hero_web/live/staff/staff_dashboard_live.ex lib/klass_hero_web/live/provider/dashboard_live.ex test/klass_hero_web/live/staff/staff_dashboard_live_test.exs test/klass_hero_web/live/provider/dashboard_live_test.exs
git commit -m "feat: add cross-navigation links between provider and staff dashboards"
```

---

### Task 11: Final verification — precommit and integration check

**Files:** None (verification only)

- [ ] **Step 1: Run precommit checks**

```bash
mix precommit
```

Expected: ALL PASS — zero warnings, all tests green, code formatted.

- [ ] **Step 2: Verify with Tidewave MCP — end-to-end check**

Use `execute_sql_query`:

```sql
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'providers'
ORDER BY ordinal_position;
```

Verify `originated_from` column exists with correct default.

Use `get_ecto_schemas` to confirm schema reflects new field.

Use `get_logs` to check for any warnings or errors during test runs.

- [ ] **Step 3: Verify the provider_profile_fixture still works**

Use `project_eval`:

```elixir
alias KlassHero.ProviderFixtures
profile = ProviderFixtures.provider_profile_fixture()
IO.inspect(profile.originated_from, label: "originated_from")
```

Expected: `:direct` (default).

- [ ] **Step 4: Run the full test suite one more time**

```bash
mix test
```

Expected: ALL PASS.
