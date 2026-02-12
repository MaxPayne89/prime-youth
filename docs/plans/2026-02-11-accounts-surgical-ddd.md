# Accounts Surgical DDD Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Apply DDD structure surgically to the Accounts context — extract use cases, add domain model + port + repository — while leaving auth infrastructure (tokens, sessions, passwords) untouched.

**Architecture:** Move schema to DDD directory (keep module name). Add pure domain model, port, repository, mapper. Extract 6 use cases from the 528-line facade. Extract shared `TokenCleanup` helper. Auth plumbing stays in facade.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, Ecto, Bcrypt

---

## Task 1: Move Schema to DDD Directory

**Files:**
- Move: `lib/klass_hero/accounts/user.ex` -> `lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex`

**Step 1: Create directory and move file**

```bash
mkdir -p lib/klass_hero/accounts/adapters/driven/persistence/schemas
git mv lib/klass_hero/accounts/user.ex lib/klass_hero/accounts/adapters/driven/persistence/schemas/user.ex
```

Module name stays `KlassHero.Accounts.User` — Elixir resolves by module name, not file path. Zero functional change.

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: PASS (0 warnings, 0 errors)

**Step 3: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor(accounts): move User schema to DDD directory structure

File relocated to adapters/driven/persistence/schemas/ to match
the project's DDD directory convention. Module name unchanged —
all external references continue to resolve."
```

---

## Task 2: Create Domain Model

**Files:**
- Create: `lib/klass_hero/accounts/domain/models/user.ex`
- Test: `test/klass_hero/accounts/domain/models/user_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule KlassHero.Accounts.Domain.Models.UserTest do
  use ExUnit.Case, async: true

  alias KlassHero.Accounts.Domain.Models.User

  describe "new/1" do
    test "creates user with valid attrs" do
      attrs = %{
        id: Ecto.UUID.generate(),
        email: "test@example.com",
        name: "Jane Doe",
        intended_roles: [:parent]
      }

      assert {:ok, %User{} = user} = User.new(attrs)
      assert user.email == "test@example.com"
      assert user.name == "Jane Doe"
      assert user.intended_roles == [:parent]
    end

    test "returns error when email is missing" do
      attrs = %{
        id: Ecto.UUID.generate(),
        name: "Jane Doe",
        intended_roles: [:parent]
      }

      assert {:error, errors} = User.new(attrs)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "Email"))
    end

    test "returns error when name is missing" do
      attrs = %{
        id: Ecto.UUID.generate(),
        email: "test@example.com",
        intended_roles: [:parent]
      }

      assert {:error, errors} = User.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "Name"))
    end

    test "returns error when email is empty" do
      attrs = %{
        id: Ecto.UUID.generate(),
        email: "  ",
        name: "Jane Doe",
        intended_roles: [:parent]
      }

      assert {:error, errors} = User.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "Email"))
    end
  end

  describe "from_persistence/1" do
    test "reconstructs user from valid persistence data" do
      attrs = %{
        id: Ecto.UUID.generate(),
        email: "test@example.com",
        name: "Jane Doe",
        intended_roles: [:parent],
        locale: "en",
        is_admin: false,
        confirmed_at: DateTime.utc_now(:second),
        inserted_at: DateTime.utc_now(:second),
        updated_at: DateTime.utc_now(:second)
      }

      assert {:ok, %User{}} = User.from_persistence(attrs)
    end

    test "returns error for missing required keys" do
      assert {:error, :invalid_persistence_data} = User.from_persistence(%{id: "123"})
    end
  end

  describe "anonymized_attrs/0" do
    test "returns canonical anonymization values" do
      attrs = User.anonymized_attrs()

      assert attrs.name == "Deleted User"
      assert attrs.avatar == nil
      assert is_function(attrs.email_fn, 1)
      assert attrs.email_fn.("abc-123") == "deleted_abc-123@anonymized.local"
    end
  end

  describe "valid?/1" do
    test "returns true for valid user" do
      {:ok, user} =
        User.new(%{
          id: Ecto.UUID.generate(),
          email: "test@example.com",
          name: "Jane",
          intended_roles: [:parent]
        })

      assert User.valid?(user)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/accounts/domain/models/user_test.exs`
Expected: FAIL — module not found

**Step 3: Write the implementation**

```elixir
defmodule KlassHero.Accounts.Domain.Models.User do
  @moduledoc """
  User domain entity in the Accounts bounded context.

  Pure domain model with no persistence or infrastructure concerns.
  Excludes auth infrastructure fields (password, hashed_password,
  authenticated_at) which live on the Ecto schema only.

  ## Fields

  - `id` - Unique identifier
  - `email` - User's email address
  - `name` - Display name
  - `avatar` - Optional avatar URL
  - `confirmed_at` - When email was confirmed
  - `is_admin` - Admin flag
  - `locale` - Preferred locale (en, de)
  - `intended_roles` - Roles selected at registration
  - `inserted_at` - Record creation timestamp
  - `updated_at` - Record update timestamp
  """

  @enforce_keys [:id, :email, :name]
  defstruct [
    :id,
    :email,
    :name,
    :avatar,
    :confirmed_at,
    :is_admin,
    :locale,
    :inserted_at,
    :updated_at,
    intended_roles: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          email: String.t(),
          name: String.t(),
          avatar: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          is_admin: boolean() | nil,
          locale: String.t() | nil,
          intended_roles: [atom()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a new User with business validation.

  Returns:
  - `{:ok, user}` if all validations pass
  - `{:error, [reasons]}` with list of validation errors
  """
  def new(attrs) when is_map(attrs) do
    user = struct!(__MODULE__, attrs)

    case validate(user) do
      [] -> {:ok, user}
      errors -> {:error, errors}
    end
  rescue
    ArgumentError -> {:error, ["Missing required fields"]}
  end

  @doc """
  Reconstructs a User from persistence data.

  Skips business validation since data was validated on write.
  """
  def from_persistence(attrs) when is_map(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    ArgumentError -> {:error, :invalid_persistence_data}
  end

  @doc """
  Returns canonical GDPR anonymization values.

  The domain model owns the definition of what "anonymized" means,
  keeping this business decision out of persistence adapters.
  """
  def anonymized_attrs do
    %{
      name: "Deleted User",
      avatar: nil,
      email_fn: fn user_id -> "deleted_#{user_id}@anonymized.local" end
    }
  end

  @doc """
  Validates that a user struct has valid business rules.
  """
  def valid?(%__MODULE__{} = user) do
    validate(user) == []
  end

  defp validate(%__MODULE__{} = user) do
    []
    |> validate_email(user.email)
    |> validate_name(user.name)
  end

  defp validate_email(errors, email) when is_binary(email) do
    if String.trim(email) == "" do
      ["Email cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_email(errors, _), do: ["Email must be a string" | errors]

  defp validate_name(errors, name) when is_binary(name) do
    if String.trim(name) == "" do
      ["Name cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_name(errors, _), do: ["Name must be a string" | errors]
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/accounts/domain/models/user_test.exs`
Expected: All tests PASS

**Step 5: Run full suite to verify no regressions**

Run: `mix compile --warnings-as-errors && mix test`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/klass_hero/accounts/domain/models/user.ex test/klass_hero/accounts/domain/models/user_test.exs
git commit -m "feat(accounts): add User domain model

Pure struct with validation, from_persistence, and anonymized_attrs.
No auth infrastructure fields (password, hashed_password) — those
stay on the Ecto schema."
```

---

## Task 3: Create Mapper

**Files:**
- Create: `lib/klass_hero/accounts/adapters/driven/persistence/mappers/user_mapper.ex`
- Test: `test/klass_hero/accounts/adapters/driven/persistence/mappers/user_mapper_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule KlassHero.Accounts.Adapters.Driven.Persistence.Mappers.UserMapperTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Accounts.Adapters.Driven.Persistence.Mappers.UserMapper
  alias KlassHero.Accounts.Domain.Models.User, as: DomainUser

  describe "to_domain/1" do
    test "converts User schema to domain model" do
      schema = user_fixture()

      domain_user = UserMapper.to_domain(schema)

      assert %DomainUser{} = domain_user
      assert domain_user.id == schema.id
      assert domain_user.email == schema.email
      assert domain_user.name == schema.name
      assert domain_user.locale == schema.locale
      assert domain_user.is_admin == schema.is_admin
      assert domain_user.intended_roles == schema.intended_roles
      assert domain_user.confirmed_at == schema.confirmed_at
    end

    test "excludes auth infrastructure fields" do
      schema = user_fixture() |> set_password()

      domain_user = UserMapper.to_domain(schema)

      refute Map.has_key?(domain_user, :password)
      refute Map.has_key?(domain_user, :hashed_password)
      refute Map.has_key?(domain_user, :authenticated_at)
    end
  end

  describe "to_domain_list/1" do
    test "converts list of schemas" do
      user1 = user_fixture()
      user2 = user_fixture()

      result = UserMapper.to_domain_list([user1, user2])

      assert length(result) == 2
      assert Enum.all?(result, &match?(%DomainUser{}, &1))
    end

    test "returns empty list for empty input" do
      assert [] == UserMapper.to_domain_list([])
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/accounts/adapters/driven/persistence/mappers/user_mapper_test.exs`
Expected: FAIL — module not found

**Step 3: Write the implementation**

```elixir
defmodule KlassHero.Accounts.Adapters.Driven.Persistence.Mappers.UserMapper do
  @moduledoc """
  Maps between the User Ecto schema and User domain entity.

  One-directional (read path only):
  - `to_domain/1`: User schema -> Domain.Models.User
  - `to_domain_list/1`: convenience for collections

  No `to_schema/1` — use cases work with the Ecto schema directly
  for mutations, since changesets need the schema struct.
  """

  alias KlassHero.Accounts.Domain.Models.User, as: DomainUser
  alias KlassHero.Accounts.User

  require Logger

  @doc """
  Converts a User schema (from database) to a User domain entity.

  Routes through `from_persistence/1` to enforce `@enforce_keys`.
  Raises on corrupted data.
  """
  def to_domain(%User{} = schema) do
    attrs = %{
      id: schema.id,
      email: schema.email,
      name: schema.name,
      avatar: schema.avatar,
      confirmed_at: schema.confirmed_at,
      is_admin: schema.is_admin,
      locale: schema.locale,
      intended_roles: schema.intended_roles || [],
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }

    case DomainUser.from_persistence(attrs) do
      {:ok, user} ->
        user

      {:error, :invalid_persistence_data} ->
        Logger.error("[UserMapper] Corrupted persistence data",
          user_id: schema.id
        )

        raise "Corrupted user data for id=#{inspect(schema.id)} — required keys missing"
    end
  end

  @doc """
  Converts a list of User schemas to domain entities.
  """
  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/accounts/adapters/driven/persistence/mappers/user_mapper_test.exs`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add lib/klass_hero/accounts/adapters/driven/persistence/mappers/user_mapper.ex test/klass_hero/accounts/adapters/driven/persistence/mappers/user_mapper_test.exs
git commit -m "feat(accounts): add UserMapper for schema-to-domain conversion

Read-path only mapper. No to_schema since use cases work with
Ecto schemas directly for mutations."
```

---

## Task 4: Create Port and Repository

**Files:**
- Create: `lib/klass_hero/accounts/domain/ports/for_storing_users.ex`
- Create: `lib/klass_hero/accounts/adapters/driven/persistence/repositories/user_repository.ex`
- Test: `test/klass_hero/accounts/adapters/driven/persistence/repositories/user_repository_test.exs`
- Modify: `config/config.exs`

**Step 1: Write the port (no test needed — it's a behaviour)**

```elixir
defmodule KlassHero.Accounts.Domain.Ports.ForStoringUsers do
  @moduledoc """
  Port for user persistence operations in the Accounts bounded context.

  Defines the contract for retrieving users without exposing infrastructure
  details. Read-only operations that return domain models.

  Infrastructure errors (connection, query) are not caught — they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Accounts.Domain.Models.User

  @doc """
  Retrieves a user by their unique identifier.

  Returns:
  - `{:ok, User.t()}` - User found
  - `{:error, :not_found}` - No user with this ID
  """
  @callback get_by_id(binary()) :: {:ok, User.t()} | {:error, :not_found}

  @doc """
  Retrieves a user by email address.

  Returns:
  - `{:ok, User.t()}` - User found
  - `nil` - No user with this email
  """
  @callback get_by_email(String.t()) :: {:ok, User.t()} | nil

  @doc """
  Checks if a user exists with the given ID.
  """
  @callback exists?(binary()) :: boolean()
end
```

**Step 2: Write the failing test for repository**

```elixir
defmodule KlassHero.Accounts.Adapters.Driven.Persistence.Repositories.UserRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Accounts.Adapters.Driven.Persistence.Repositories.UserRepository
  alias KlassHero.Accounts.Domain.Models.User, as: DomainUser

  describe "get_by_id/1" do
    test "returns domain user when found" do
      schema = user_fixture()

      assert {:ok, %DomainUser{} = user} = UserRepository.get_by_id(schema.id)
      assert user.id == schema.id
      assert user.email == schema.email
    end

    test "returns error when not found" do
      assert {:error, :not_found} =
               UserRepository.get_by_id("00000000-0000-0000-0000-000000000000")
    end
  end

  describe "get_by_email/1" do
    test "returns domain user when found" do
      schema = user_fixture()

      assert {:ok, %DomainUser{} = user} = UserRepository.get_by_email(schema.email)
      assert user.email == schema.email
    end

    test "returns nil when not found" do
      assert nil == UserRepository.get_by_email("nonexistent@example.com")
    end
  end

  describe "exists?/1" do
    test "returns true when user exists" do
      schema = user_fixture()
      assert UserRepository.exists?(schema.id)
    end

    test "returns false when user does not exist" do
      refute UserRepository.exists?("00000000-0000-0000-0000-000000000000")
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `mix test test/klass_hero/accounts/adapters/driven/persistence/repositories/user_repository_test.exs`
Expected: FAIL — module not found

**Step 4: Write the repository implementation**

```elixir
defmodule KlassHero.Accounts.Adapters.Driven.Persistence.Repositories.UserRepository do
  @moduledoc """
  Repository implementation for user persistence.

  Implements ForStoringUsers with domain entity mapping via UserMapper.
  Read-only operations — mutations go through use cases with Ecto schemas.

  Infrastructure errors (connection, query) are not caught — they crash
  and are handled by the supervision tree.
  """

  @behaviour KlassHero.Accounts.Domain.Ports.ForStoringUsers

  import Ecto.Query

  alias KlassHero.Accounts.Adapters.Driven.Persistence.Mappers.UserMapper
  alias KlassHero.Accounts.User
  alias KlassHero.Repo

  @impl true
  def get_by_id(user_id) when is_binary(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, UserMapper.to_domain(schema)}
    end
  end

  @impl true
  def get_by_email(email) when is_binary(email) do
    case Repo.get_by(User, email: email) do
      nil -> nil
      schema -> {:ok, UserMapper.to_domain(schema)}
    end
  end

  @impl true
  def exists?(user_id) when is_binary(user_id) do
    User
    |> where([u], u.id == ^user_id)
    |> Repo.exists?()
  end
end
```

**Step 5: Add config for accounts repository**

In `config/config.exs`, add after the Community config block (line 65):

```elixir
# Configure Accounts bounded context
config :klass_hero, :accounts,
  for_storing_users:
    KlassHero.Accounts.Adapters.Driven.Persistence.Repositories.UserRepository
```

**Step 6: Run tests to verify**

Run: `mix test test/klass_hero/accounts/adapters/driven/persistence/repositories/user_repository_test.exs`
Expected: All tests PASS

Run: `mix compile --warnings-as-errors && mix test`
Expected: Full suite PASS

**Step 7: Commit**

```bash
git add lib/klass_hero/accounts/domain/ports/for_storing_users.ex lib/klass_hero/accounts/adapters/driven/persistence/repositories/user_repository.ex test/klass_hero/accounts/adapters/driven/persistence/repositories/user_repository_test.exs config/config.exs
git commit -m "feat(accounts): add ForStoringUsers port and UserRepository

Read-only repository returning domain models via UserMapper.
Config-based injection following Identity context pattern."
```

---

## Task 5: Extract TokenCleanup Helper

**Files:**
- Create: `lib/klass_hero/accounts/token_cleanup.ex`
- Modify: `lib/klass_hero/accounts.ex` (remove private function, import helper)

**Step 1: Create the TokenCleanup module**

Extract `update_user_and_delete_all_tokens/1` from `accounts.ex` (lines 403-419):

```elixir
defmodule KlassHero.Accounts.TokenCleanup do
  @moduledoc """
  Shared helper for updating a user and deleting all their tokens.

  Used by both the Accounts facade (password updates) and use cases
  (magic link login) that need to atomically update a user and
  invalidate all existing sessions.
  """

  import Ecto.Query, warn: false

  alias KlassHero.Accounts.UserToken
  alias KlassHero.Repo

  @doc """
  Updates a user via changeset and deletes all their tokens atomically.

  Returns `{:ok, {user, tokens}}` on success or `{:error, changeset}` on failure.
  The returned tokens are the ones that were deleted (for session invalidation).
  """
  def update_user_and_delete_all_tokens(changeset) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:update_user, changeset)
    |> Ecto.Multi.run(:fetch_tokens, fn repo, %{update_user: user} ->
      tokens = repo.all_by(UserToken, user_id: user.id)
      {:ok, tokens}
    end)
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{fetch_tokens: tokens} ->
      from(t in UserToken, where: t.id in ^Enum.map(tokens, & &1.id))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_user: user, fetch_tokens: tokens}} -> {:ok, {user, tokens}}
      {:error, :update_user, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end
end
```

**Step 2: Update accounts.ex — replace private function with import**

In `lib/klass_hero/accounts.ex`:
- Add `alias KlassHero.Accounts.TokenCleanup` near top aliases
- Replace calls to `update_user_and_delete_all_tokens(changeset)` with `TokenCleanup.update_user_and_delete_all_tokens(changeset)`
- Remove the private `defp update_user_and_delete_all_tokens/1` (lines 403-419)

The two call sites are:
- `update_user_password/2` (line 218)
- `login_user_by_magic_link/1` (line 343)

**Step 3: Verify nothing breaks**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Full suite PASS — this is a pure refactor, no behavior change

**Step 4: Commit**

```bash
git add lib/klass_hero/accounts/token_cleanup.ex lib/klass_hero/accounts.ex
git commit -m "refactor(accounts): extract TokenCleanup shared helper

Moves update_user_and_delete_all_tokens from private facade function
to standalone module. Used by both facade and use cases."
```

---

## Task 6: Extract RegisterUser Use Case

**Files:**
- Create: `lib/klass_hero/accounts/application/use_cases/register_user.ex`
- Modify: `lib/klass_hero/accounts.ex`

**Step 1: Create the use case**

```elixir
defmodule KlassHero.Accounts.Application.UseCases.RegisterUser do
  @moduledoc """
  Use case for registering a new user.

  Orchestrates user creation and domain event dispatch.
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Accounts.User
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  @doc """
  Registers a new user with the given attributes.

  Returns:
  - `{:ok, %User{}}` on success (dispatches user_registered event)
  - `{:error, %Ecto.Changeset{}}` on validation failure
  """
  def execute(attrs) when is_map(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        DomainEventBus.dispatch(
          KlassHero.Accounts,
          UserEvents.user_registered(user, %{registration_source: :web})
        )

        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
```

**Step 2: Update facade to delegate**

In `lib/klass_hero/accounts.ex`, replace the `register_user/1` function body (lines 79-95) with:

```elixir
def register_user(attrs) do
  KlassHero.Accounts.Application.UseCases.RegisterUser.execute(attrs)
end
```

**Step 3: Verify existing tests pass**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Full suite PASS — contract unchanged

**Step 4: Commit**

```bash
git add lib/klass_hero/accounts/application/use_cases/register_user.ex lib/klass_hero/accounts.ex
git commit -m "refactor(accounts): extract RegisterUser use case

Moves registration + event dispatch from facade to dedicated use case."
```

---

## Task 7: Extract LoginByMagicLink Use Case

**Files:**
- Create: `lib/klass_hero/accounts/application/use_cases/login_by_magic_link.ex`
- Modify: `lib/klass_hero/accounts.ex`

**Step 1: Create the use case**

```elixir
defmodule KlassHero.Accounts.Application.UseCases.LoginByMagicLink do
  @moduledoc """
  Use case for logging in a user via magic link token.

  Handles three scenarios:
  1. Confirmed user — logs in, expires magic link token
  2. Unconfirmed user (no password) — confirms email, logs in, expires all tokens
  3. Unconfirmed user (has password) — raises security error
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Accounts.{TokenCleanup, User, UserToken}
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  @doc """
  Logs in a user by magic link token.

  Returns:
  - `{:ok, {%User{}, expired_tokens}}` on success
  - `{:error, :not_found}` if token is invalid/expired
  - Raises on unconfirmed user with password (security violation)
  """
  def execute(token) when is_binary(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Trigger: unconfirmed user has a password set
      # Why: prevents session fixation attacks via magic link
      # Outcome: raises — this state should not occur in default implementation
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      # Trigger: unconfirmed user without password (normal registration flow)
      # Why: first login confirms the email
      # Outcome: user confirmed, all tokens expired, user_confirmed event dispatched
      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> TokenCleanup.update_user_and_delete_all_tokens()
        |> case do
          {:ok, {confirmed_user, tokens}} ->
            DomainEventBus.dispatch(
              KlassHero.Accounts,
              UserEvents.user_confirmed(confirmed_user, %{confirmation_method: :magic_link})
            )

            {:ok, {confirmed_user, tokens}}

          error ->
            error
        end

      # Trigger: confirmed user clicking magic link
      # Why: standard login — just expire the specific token
      # Outcome: user logged in, magic link token deleted
      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end
end
```

**Step 2: Update facade to delegate**

Replace `login_user_by_magic_link/1` (lines 326-364) with:

```elixir
def login_user_by_magic_link(token) do
  KlassHero.Accounts.Application.UseCases.LoginByMagicLink.execute(token)
end
```

**Step 3: Verify**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Full suite PASS

**Step 4: Commit**

```bash
git add lib/klass_hero/accounts/application/use_cases/login_by_magic_link.ex lib/klass_hero/accounts.ex
git commit -m "refactor(accounts): extract LoginByMagicLink use case

Moves 3-case magic link logic from facade to use case.
Uses TokenCleanup for atomic user update + token deletion."
```

---

## Task 8: Extract ChangeEmail Use Case

**Files:**
- Create: `lib/klass_hero/accounts/application/use_cases/change_email.ex`
- Modify: `lib/klass_hero/accounts.ex`

**Step 1: Create the use case**

```elixir
defmodule KlassHero.Accounts.Application.UseCases.ChangeEmail do
  @moduledoc """
  Use case for updating a user's email via confirmation token.

  Orchestrates the 5-step email change flow:
  1. Verify the change token
  2. Fetch the token + new email
  3. Update the user's email
  4. Delete all change tokens for this context
  5. Publish user_email_changed event
  """

  import Ecto.Query, warn: false

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Accounts.{User, UserToken}
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  @doc """
  Updates the user's email using the given confirmation token.

  Returns:
  - `{:ok, %User{}}` on success
  - `{:error, :invalid_token}` if token is invalid or expired
  - `{:error, changeset}` if email update fails
  """
  def execute(%User{} = user, token) when is_binary(token) do
    context = "change:#{user.email}"
    previous_email = user.email

    Ecto.Multi.new()
    |> Ecto.Multi.run(:verify_token, fn _repo, _ ->
      UserToken.verify_change_email_token_query(token, context)
    end)
    |> Ecto.Multi.run(:fetch_token, fn repo, %{verify_token: query} ->
      case repo.one(query) do
        %UserToken{sent_to: email} = token -> {:ok, {token, email}}
        nil -> {:error, :token_not_found}
      end
    end)
    |> Ecto.Multi.run(:update_email, fn repo, %{fetch_token: {_token, email}} ->
      user
      |> User.email_changeset(%{email: email})
      |> repo.update()
    end)
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{update_email: updated_user} ->
      from(UserToken, where: [user_id: ^updated_user.id, context: ^context])
    end)
    |> Ecto.Multi.run(:publish_event, fn _repo, %{update_email: updated_user} ->
      DomainEventBus.dispatch(
        KlassHero.Accounts,
        UserEvents.user_email_changed(updated_user, %{previous_email: previous_email})
      )

      {:ok, updated_user}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{publish_event: user}} -> {:ok, user}
      {:error, :verify_token, _reason, _} -> {:error, :invalid_token}
      {:error, :fetch_token, _reason, _} -> {:error, :invalid_token}
      {:error, :update_email, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end
end
```

**Step 2: Update facade to delegate**

Replace `update_user_email/2` (lines 146-184) with:

```elixir
def update_user_email(user, token) do
  KlassHero.Accounts.Application.UseCases.ChangeEmail.execute(user, token)
end
```

**Step 3: Verify**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Full suite PASS

**Step 4: Commit**

```bash
git add lib/klass_hero/accounts/application/use_cases/change_email.ex lib/klass_hero/accounts.ex
git commit -m "refactor(accounts): extract ChangeEmail use case

Moves 5-step Ecto.Multi email change flow from facade to use case."
```

---

## Task 9: Extract AnonymizeUser Use Case

**Files:**
- Create: `lib/klass_hero/accounts/application/use_cases/anonymize_user.ex`
- Modify: `lib/klass_hero/accounts.ex`

**Step 1: Create the use case**

```elixir
defmodule KlassHero.Accounts.Application.UseCases.AnonymizeUser do
  @moduledoc """
  Use case for GDPR account anonymization.

  Orchestrates:
  1. Anonymize user PII (email, name, avatar)
  2. Delete all tokens (invalidate all sessions)
  3. Publish user_anonymized event for downstream contexts
  """

  import Ecto.Query, warn: false

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Accounts.{User, UserToken}
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  @doc """
  Anonymizes a user account.

  Returns:
  - `{:ok, %User{}}` on success (dispatches user_anonymized event)
  - `{:error, :user_not_found}` if nil user
  - `{:error, changeset}` on update failure
  """
  def execute(%User{} = user) do
    previous_email = user.email

    Ecto.Multi.new()
    |> Ecto.Multi.update(:anonymize_user, User.anonymize_changeset(user))
    |> Ecto.Multi.delete_all(:delete_tokens, fn %{anonymize_user: anonymized_user} ->
      from(t in UserToken, where: t.user_id == ^anonymized_user.id)
    end)
    |> Ecto.Multi.run(:publish_event, fn _repo, %{anonymize_user: anonymized_user} ->
      DomainEventBus.dispatch(
        KlassHero.Accounts,
        UserEvents.user_anonymized(anonymized_user, %{previous_email: previous_email})
      )

      {:ok, anonymized_user}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{publish_event: user}} -> {:ok, user}
      {:error, :anonymize_user, changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def execute(nil), do: {:error, :user_not_found}
end
```

**Step 2: Update facade**

Replace `anonymize_user/1` (lines 466-490) with:

```elixir
def anonymize_user(user) do
  KlassHero.Accounts.Application.UseCases.AnonymizeUser.execute(user)
end
```

**Step 3: Verify**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Full suite PASS

**Step 4: Commit**

```bash
git add lib/klass_hero/accounts/application/use_cases/anonymize_user.ex lib/klass_hero/accounts.ex
git commit -m "refactor(accounts): extract AnonymizeUser use case

GDPR-critical path: anonymize PII, delete tokens, dispatch event."
```

---

## Task 10: Extract DeleteAccount Use Case

**Files:**
- Create: `lib/klass_hero/accounts/application/use_cases/delete_account.ex`
- Modify: `lib/klass_hero/accounts.ex`

**Step 1: Create the use case**

```elixir
defmodule KlassHero.Accounts.Application.UseCases.DeleteAccount do
  @moduledoc """
  Use case for account deletion with verification.

  Orchestrates:
  1. Verify sudo mode (recent authentication)
  2. Verify password matches
  3. Delegate to AnonymizeUser for actual deletion
  """

  alias KlassHero.Accounts
  alias KlassHero.Accounts.Application.UseCases.AnonymizeUser
  alias KlassHero.Accounts.User

  @doc """
  Deletes (anonymizes) a user account after password verification.

  Returns:
  - `{:ok, %User{}}` on success
  - `{:error, :sudo_required}` if not in sudo mode
  - `{:error, :invalid_password}` if password doesn't match
  """
  def execute(%User{} = user, password) when is_binary(password) do
    with true <- Accounts.sudo_mode?(user),
         %User{} <- Accounts.get_user_by_email_and_password(user.email, password) do
      AnonymizeUser.execute(user)
    else
      false -> {:error, :sudo_required}
      nil -> {:error, :invalid_password}
    end
  end
end
```

**Step 2: Update facade**

Replace `delete_account/2` (lines 519-527) with:

```elixir
def delete_account(user, password) do
  KlassHero.Accounts.Application.UseCases.DeleteAccount.execute(user, password)
end
```

**Step 3: Verify**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Full suite PASS

**Step 4: Commit**

```bash
git add lib/klass_hero/accounts/application/use_cases/delete_account.ex lib/klass_hero/accounts.ex
git commit -m "refactor(accounts): extract DeleteAccount use case

Orchestrates sudo check, password verification, then delegates
to AnonymizeUser."
```

---

## Task 11: Extract ExportUserData Use Case

**Files:**
- Create: `lib/klass_hero/accounts/application/use_cases/export_user_data.ex`
- Modify: `lib/klass_hero/accounts.ex`

**Step 1: Create the use case**

```elixir
defmodule KlassHero.Accounts.Application.UseCases.ExportUserData do
  @moduledoc """
  Use case for GDPR data export.

  Produces a serializable map of all personal user data.
  """

  alias KlassHero.Accounts.User

  @doc """
  Exports all personal data for the given user in GDPR-compliant format.

  Returns a map containing all user data that can be serialized to JSON.
  """
  def execute(%User{} = user) do
    %{
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      user: %{
        id: user.id,
        email: user.email,
        name: user.name,
        avatar: user.avatar,
        confirmed_at: user.confirmed_at && DateTime.to_iso8601(user.confirmed_at),
        created_at: user.inserted_at && DateTime.to_iso8601(user.inserted_at),
        updated_at: user.updated_at && DateTime.to_iso8601(user.updated_at)
      }
    }
  end
end
```

**Step 2: Update facade**

Replace `export_user_data/1` (lines 428-441) with:

```elixir
def export_user_data(user) do
  KlassHero.Accounts.Application.UseCases.ExportUserData.execute(user)
end
```

**Step 3: Verify**

Run: `mix compile --warnings-as-errors && mix test`
Expected: Full suite PASS

**Step 4: Commit**

```bash
git add lib/klass_hero/accounts/application/use_cases/export_user_data.ex lib/klass_hero/accounts.ex
git commit -m "refactor(accounts): extract ExportUserData use case

Pure data transformation for GDPR export, no side effects."
```

---

## Task 12: Clean Up Facade

**Files:**
- Modify: `lib/klass_hero/accounts.ex`

**Step 1: Organize the facade**

After all extractions, the facade should:
- Have aliases for all use cases at the top
- Group functions by section (Registration, Settings, Session, GDPR)
- Remove dead imports (UserEvents, DomainEventBus no longer used directly)
- Keep `import Ecto.Query, warn: false` only if still needed

Clean up unused aliases: `UserEvents` and `DomainEventBus` should no longer be aliased in the facade (they're in use cases now). Keep `User`, `UserNotifier`, `UserToken`, `Repo`, `TokenCleanup`.

**Step 2: Verify final state**

Run: `mix precommit`
Expected: Compile (0 warnings), format, all tests PASS

**Step 3: Commit**

```bash
git add lib/klass_hero/accounts.ex
git commit -m "refactor(accounts): clean up facade after use case extraction

Remove unused aliases, organize sections. Facade is now ~250 lines
(down from 528), delegating domain operations to use cases."
```

---

## Verification Checklist

After all tasks complete:

1. `mix precommit` — compile with `--warnings-as-errors` + format + full test suite
2. Verify directory structure matches plan: `find lib/klass_hero/accounts -type f -name "*.ex" | sort`
3. Verify event flow still works: registration -> domain event -> integration event -> Identity profile
4. Verify GDPR flow: delete_account -> anonymize -> event -> downstream anonymization
5. Check no unused modules: `mix compile --warnings-as-errors` catches unused aliases/imports

## Reference Files

| File | Purpose |
|------|---------|
| `lib/klass_hero/identity/domain/models/child.ex` | Domain model pattern |
| `lib/klass_hero/identity/application/use_cases/children/create_child.ex` | Use case pattern |
| `lib/klass_hero/identity/domain/ports/for_storing_children.ex` | Port pattern |
| `lib/klass_hero/identity/adapters/driven/persistence/repositories/child_repository.ex` | Repository pattern |
| `lib/klass_hero/identity/adapters/driven/persistence/mappers/child_mapper.ex` | Mapper pattern |
| `lib/klass_hero/accounts.ex` | Source facade (to extract from) |
| `lib/klass_hero/accounts/user.ex` | Schema to move |
| `config/config.exs` | Repository config |
| `test/support/fixtures/accounts_fixtures.ex` | Test fixtures (unchanged) |
