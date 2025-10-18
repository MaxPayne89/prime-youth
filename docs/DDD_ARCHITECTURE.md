# DDD & Ports & Adapters Architecture

Implementation guide for Domain-Driven Design with Hexagonal Architecture in Prime Youth.

## Core Principles

### The Dependency Rule
**All dependencies point INWARD**: Infrastructure → Application → Domain

- **Domain Layer**: Zero external dependencies (pure Elixir, no Ecto/HTTP/Kafka)
- **Application Layer**: Depends only on Domain
- **Infrastructure Layer**: Implements ports, depends on Application and Domain

### Key Concepts

1. **Pure Domain Models**: Domain entities are pure Elixir structs with business logic
2. **Ports as Behaviours**: Use Elixir behaviours to define contracts
3. **Adapters Implement Ports**: Infrastructure implements behaviours
4. **Thin Use Cases**: Orchestration only, logic lives in domain models
5. **Compile-Time DI**: Use `Application.compile_env!` for dependency injection

---

## Directory Structure

### Canonical Bounded Context Structure

```
lib/prime_youth/
  {bounded_context}/              # e.g., auth, program_catalog, enrollment

    domain/                       # Pure business logic - NO dependencies
      models/                     # Domain entities (pure structs, no Ecto)
        entity_name.ex
      value_objects/              # Immutable values
        value_object.ex
      ports/                      # Behaviours defining ALL contracts
        for_storing_things.ex
        for_sending_notifications.ex
      policies/                   # Business rules (optional)
        business_policy.ex

    application/                  # Use cases orchestrating domain
      use_cases/
        use_case_name.ex
      dtos/                       # Input/output validation (optional)
        request_dto.ex

    adapters/
      driven/                     # OUTBOUND: App calls these
        persistence/
          schemas/                # Ecto schemas (infrastructure!)
            entity_schema.ex
          mappers/                # Domain ↔ Schema conversion
            entity_mapper.ex
          repositories/           # Port implementations
            entity_repository.ex
        http_clients/
          external_client.ex
        notifications/
          email_notifier.ex

    infrastructure/               # Cross-cutting concerns
      scope.ex                    # Shared infrastructure utilities
```

---

## Code Patterns

### 1. Domain Entity (Pure Model)

**Location**: `domain/models/user.ex`

```elixir
defmodule PrimeYouth.Auth.Domain.Models.User do
  @moduledoc "Domain entity representing a user (pure logic, no dependencies)"

  @type t :: %__MODULE__{
    id: String.t() | nil,
    email: String.t(),
    first_name: String.t() | nil,
    hashed_password: String.t() | nil,
    confirmed_at: DateTime.t() | nil
  }

  @enforce_keys [:email]
  defstruct [:id, :email, :first_name, :hashed_password, :confirmed_at]

  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @doc "Creates a new user with validation"
  def new(attrs) do
    with {:ok, email} <- validate_email(attrs[:email]),
         {:ok, first_name} <- validate_name(attrs[:first_name]) do
      {:ok, %__MODULE__{email: email, first_name: first_name}}
    end
  end

  @doc "Confirms user account"
  def confirm(%__MODULE__{} = user, confirmed_at) do
    %{user | confirmed_at: confirmed_at}
  end

  @doc "Validates email according to domain rules"
  def validate_email(nil), do: {:error, :email_required}
  def validate_email(""), do: {:error, :email_required}
  def validate_email(email) when is_binary(email) do
    email = String.trim(email)
    cond do
      String.length(email) > 160 -> {:error, :email_too_long}
      not Regex.match?(@email_regex, email) -> {:error, :invalid_email}
      true -> {:ok, String.downcase(email)}
    end
  end
  def validate_email(_), do: {:error, :invalid_email}

  # ... more domain logic
end
```

**Key Characteristics:**
- Pure Elixir struct, no Ecto dependencies
- All business logic encapsulated
- Self-validating through functions
- Immutable (all operations return new struct)

---

### 2. Port (Behaviour)

**Location**: `domain/ports/for_storing_users.ex`

```elixir
defmodule PrimeYouth.Auth.Domain.Ports.ForStoringUsers do
  @moduledoc "Port (interface) for user persistence"

  alias PrimeYouth.Auth.Domain.Models.User

  @callback save(User.t()) :: {:ok, User.t()} | {:error, term()}
  @callback find_by_id(String.t()) :: {:ok, User.t()} | {:error, :not_found}
  @callback find_by_email(String.t()) :: {:ok, User.t()} | {:error, :not_found}
  @callback delete(String.t()) :: :ok | {:error, term()}
end
```

**Naming Convention**: `for_<action>_<noun>` makes dependencies explicit

**Example Ports:**
- `for_storing_users.ex` - Persistence
- `for_hashing_passwords.ex` - Cryptography
- `for_sending_notifications.ex` - Email/Notifications

---

### 3. Use Case (Thin Orchestration)

**Location**: `application/use_cases/register_user.ex`

```elixir
defmodule PrimeYouth.Auth.Application.UseCases.RegisterUser do
  @moduledoc "Use case for user registration (orchestrates domain and adapters)"

  alias PrimeYouth.Auth.Domain.Models.User

  @user_repository Application.compile_env!(:prime_youth, :user_repository)
  @password_hasher Application.compile_env!(:prime_youth, :password_hasher)
  @notifier Application.compile_env!(:prime_youth, :notifier)

  def execute(attrs) do
    with {:ok, user} <- User.new(attrs),
         {:ok, hashed} <- @password_hasher.hash(attrs[:password]),
         user_with_password = %{user | hashed_password: hashed},
         {:ok, saved} <- @user_repository.save(user_with_password),
         :ok <- @notifier.send_confirmation_email(saved) do
      {:ok, saved}
    end
  end
end
```

**Key Characteristics:**
- Pure orchestration, no business logic
- Dependencies injected via `Application.compile_env!`
- Returns `{:ok, result}` or `{:error, reason}` tuples
- Handles cross-adapter coordination

---

### 4. Ecto Schema (Infrastructure)

**Location**: `adapters/driven/persistence/schemas/user_schema.ex`

```elixir
defmodule PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserSchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :hashed_password, :string
    field :confirmed_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:email, :first_name, :hashed_password, :confirmed_at])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end
```

**Key Characteristics:**
- Ecto-specific (infrastructure detail)
- Validation focuses on data integrity, not business rules
- Located deep in adapters layer
- Only used by repository adapter

---

### 5. Mapper (Bidirectional Translation)

**Location**: `adapters/driven/persistence/mappers/user_mapper.ex`

```elixir
defmodule PrimeYouth.Auth.Adapters.Driven.Persistence.Mappers.UserMapper do
  @moduledoc "Maps between domain User model and Ecto UserSchema"

  alias PrimeYouth.Auth.Domain.Models.User
  alias PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserSchema

  @doc "Converts domain User to Ecto schema for database operations"
  def to_schema(%User{} = user) do
    %UserSchema{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      hashed_password: user.hashed_password,
      confirmed_at: user.confirmed_at
    }
  end

  @doc "Converts Ecto schema to domain User"
  def to_domain(%UserSchema{} = schema) do
    %User{
      id: schema.id,
      email: schema.email,
      first_name: schema.first_name,
      hashed_password: schema.hashed_password,
      confirmed_at: schema.confirmed_at
    }
  end
end
```

**Key Characteristics:**
- Eliminates mapping logic from repository
- Single responsibility: translation only
- Handles all domain ↔ schema conversions
- Testable in isolation

---

### 6. Repository Adapter (Port Implementation)

**Location**: `adapters/driven/persistence/repositories/user_repository.ex`

```elixir
defmodule PrimeYouth.Auth.Adapters.Driven.Persistence.Repositories.UserRepository do
  @behaviour PrimeYouth.Auth.Domain.Ports.ForStoringUsers

  alias PrimeYouth.Repo
  alias PrimeYouth.Auth.Adapters.Driven.Persistence.{
    Schemas.UserSchema,
    Mappers.UserMapper
  }

  @impl true
  def save(user) do
    user
    |> UserMapper.to_schema()
    |> Repo.insert_or_update()
    |> case do
      {:ok, schema} -> {:ok, UserMapper.to_domain(schema)}
      {:error, _} = error -> error
    end
  end

  @impl true
  def find_by_id(id) do
    case Repo.get(UserSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, UserMapper.to_domain(schema)}
    end
  end

  @impl true
  def find_by_email(email) do
    case Repo.get_by(UserSchema, email: email) do
      nil -> {:error, :not_found}
      schema -> {:ok, UserMapper.to_domain(schema)}
    end
  end

  @impl true
  def delete(id) do
    case Repo.delete(Repo.get!(UserSchema, id)) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
```

**Key Characteristics:**
- Implements port behaviour
- Uses mapper for domain ↔ schema translation
- All database queries here
- No business logic

---

### 7. Password Hasher Adapter

**Location**: `adapters/driven/password_hashing/bcrypt_password_hasher.ex`

```elixir
defmodule PrimeYouth.Auth.Adapters.Driven.PasswordHashing.BcryptPasswordHasher do
  @behaviour PrimeYouth.Auth.Domain.Ports.ForHashingPasswords

  @impl true
  def hash(password) do
    case Bcrypt.hash_pwd_salt(password) do
      hash when is_binary(hash) -> {:ok, hash}
      _ -> {:error, :hashing_failed}
    end
  end

  @impl true
  def verify(password, hashed) do
    Bcrypt.verify_pass(password, hashed)
  end
end
```

---

### 8. Email Notifier Adapter

**Location**: `adapters/driven/notifications/email_notifier.ex`

```elixir
defmodule PrimeYouth.Auth.Adapters.Driven.Notifications.EmailNotifier do
  @behaviour PrimeYouth.Auth.Domain.Ports.ForSendingNotifications

  alias PrimeYouth.Auth.Infrastructure.UserNotifier

  @impl true
  def send_confirmation_email(user) do
    UserNotifier.deliver_confirmation_instructions(user)
  end

  @impl true
  def send_password_reset_email(user) do
    UserNotifier.deliver_reset_password_instructions(user)
  end
end
```

---

### 9. Web Controller (Driving Adapter)

**Location**: `lib/prime_youth_web/live/user_registration_live.ex`

```elixir
defmodule PrimeYouthWeb.UserRegistrationLive do
  use PrimeYouthWeb, :live_view

  alias PrimeYouth.Auth.Application.UseCases.RegisterUser

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("register", %{"user" => user_params}, socket) do
    case RegisterUser.execute(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Registration successful")
         |> redirect(to: "/")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  defp format_error(:email_required), do: "Email is required"
  defp format_error(:invalid_email), do: "Invalid email format"
  defp format_error(_), do: "Registration failed"
end
```

---

## Dependency Injection

### Configuration Pattern

**config/config.exs:**
```elixir
config :prime_youth,
  user_repository: PrimeYouth.Auth.Adapters.Driven.Persistence.Repositories.UserRepository,
  password_hasher: PrimeYouth.Auth.Adapters.Driven.PasswordHashing.BcryptPasswordHasher,
  notifier: PrimeYouth.Auth.Adapters.Driven.Notifications.EmailNotifier
```

**config/test.exs:**
```elixir
config :prime_youth,
  user_repository: PrimeYouth.Auth.Test.InMemoryUserRepository,
  password_hasher: PrimeYouth.Auth.Test.NoOpPasswordHasher,
  notifier: PrimeYouth.Auth.Test.TestNotifier
```

**In use case:**
```elixir
@user_repository Application.compile_env!(:prime_youth, :user_repository)

def execute(attrs) do
  @user_repository.save(user)
end
```

**Benefits:**
- Easy to swap implementations
- Test doubles without mocking libraries
- Clear adapter dependencies
- Compile-time safety

---

## Testing Patterns

### Domain Model Tests

```elixir
# test/prime_youth/auth/domain/models/user_test.exs
test "validates email format" do
  assert {:error, :invalid_email} = User.validate_email("not-an-email")
  assert {:ok, "test@example.com"} = User.validate_email("test@example.com")
end

test "confirms user account" do
  user = %User{email: "test@example.com", confirmed_at: nil}
  now = DateTime.utc_now()
  confirmed = User.confirm(user, now)
  assert confirmed.confirmed_at == now
end
```

### Use Case Tests (with test doubles)

```elixir
# test/prime_youth/auth/application/use_cases/register_user_test.exs
test "registers user successfully" do
  assert {:ok, user} = RegisterUser.execute(%{
    email: "test@example.com",
    password: "secure123"
  })
  assert user.email == "test@example.com"
end
```

### Repository Tests (integration)

```elixir
# test/prime_youth/auth/adapters/driven/persistence/repositories/user_repository_test.exs
test "saves and retrieves user" do
  user = User.new(%{email: "test@example.com"})
  {:ok, saved} = UserRepository.save(user)
  {:ok, retrieved} = UserRepository.find_by_id(saved.id)
  assert retrieved.email == "test@example.com"
end
```

---

## Migration Strategy

### For New Bounded Contexts
1. Start with DDD structure from day one
2. Extract domain models (pure structs)
3. Define ports (behaviours)
4. Implement adapters
5. Create use cases
6. Update controllers

### For Existing Code
**Gradual migration** - coexist old and new:

1. Identify bounded context
2. Create DDD structure alongside existing code
3. Move functionality incrementally
4. Provide adapters for legacy integration
5. Remove old code once migrated

---

## When to Use DDD

### Use DDD Structure When:
- Complex business rules
- Clear bounded contexts
- Multiple teams/modules
- High testability needs
- Long-term maintainability critical

### Keep It Simple When:
- Pure CRUD operations
- Simple transformations
- Internal utilities
- Quick prototypes
- Configuration/setup code

---

## Bounded Contexts in Prime Youth

1. **Auth Context** ✅ (Implemented)
   - User management, authentication, authorization

2. **Program Catalog Context** (Ready for DDD)
   - Program discovery, details, availability
   - Categories, schedules, pricing

3. **Enrollment Context** (Ready for DDD)
   - Enrollment process, child selection, payments

4. **Family Management Context** (Ready for DDD)
   - Family profiles, children, relationships

5. **Progress Tracking Context** (Ready for DDD)
   - Session tracking, achievements, milestones

6. **Review & Rating Context** (Ready for DDD)
   - Program reviews, ratings, moderation

---

## Key Files to Reference

See project documentation:
- [domain-stories.md](./domain-stories.md) - Business domain understanding
- [technical-architecture.md](./technical-architecture.md) - Architecture overview
- Auth context implementation - Production example

---

## Quick Reference

| Layer | Location | Purpose | Example |
|-------|----------|---------|---------|
| **Domain** | `domain/models/` | Pure business logic | User entity |
| **Domain** | `domain/ports/` | Interface definitions | `ForStoringUsers` behaviour |
| **Application** | `application/use_cases/` | Orchestration | RegisterUser use case |
| **Adapters** | `adapters/driven/persistence/` | Database access | EctoUserRepository |
| **Adapters** | `adapters/driven/password_hashing/` | External services | BcryptPasswordHasher |
| **Infrastructure** | `infrastructure/` | Cross-cutting | Scope, shared utilities |

