# Inbound Email Receiving Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Also use: superpowers:test-driven-development and idiomatic-elixir skills.

**Goal:** Enable admins to receive, read, and reply to inbound emails via Resend webhooks, with safe HTML rendering.

**Architecture:** Extend Messaging bounded context with new `InboundEmail` domain model, repository port/adapter, use cases, and a custom admin LiveView. Webhook controller receives Resend payloads with Svix signature verification.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Ecto, Swoosh/Resend, html_sanitize_ex, svix

**Spec:** `docs/superpowers/specs/2026-03-20-inbound-email-receiving-design.md`

---

## File Map

### New files

```
# Dependencies & config
mix.exs                                          # Add html_sanitize_ex, svix deps
config/config.exs                                # Add :for_managing_inbound_emails to messaging config
config/runtime.exs                               # Add RESEND_WEBHOOK_SECRET

# Domain layer
lib/klass_hero/messaging/domain/models/inbound_email.ex
lib/klass_hero/messaging/domain/ports/for_managing_inbound_emails.ex

# Persistence layer
priv/repo/migrations/TIMESTAMP_create_inbound_emails.exs
lib/klass_hero/messaging/adapters/driven/persistence/schemas/inbound_email_schema.ex
lib/klass_hero/messaging/adapters/driven/persistence/mappers/inbound_email_mapper.ex
lib/klass_hero/messaging/adapters/driven/persistence/queries/inbound_email_queries.ex
lib/klass_hero/messaging/adapters/driven/persistence/repositories/inbound_email_repository.ex

# Sanitization
lib/klass_hero/messaging/adapters/driven/email_sanitizer.ex

# Use cases
lib/klass_hero/messaging/application/use_cases/receive_inbound_email.ex
lib/klass_hero/messaging/application/use_cases/list_inbound_emails.ex
lib/klass_hero/messaging/application/use_cases/get_inbound_email.ex
lib/klass_hero/messaging/application/use_cases/reply_to_email.ex

# Webhook
lib/klass_hero_web/plugs/cache_raw_body.ex
lib/klass_hero_web/controllers/resend_webhook_controller.ex

# Admin UI
lib/klass_hero_web/live/admin/emails_live.ex

# Tests
test/klass_hero/messaging/domain/models/inbound_email_test.exs
test/klass_hero/messaging/adapters/driven/email_sanitizer_test.exs
test/klass_hero/messaging/adapters/driven/persistence/repositories/inbound_email_repository_test.exs
test/klass_hero/messaging/application/use_cases/receive_inbound_email_test.exs
test/klass_hero/messaging/application/use_cases/list_inbound_emails_test.exs
test/klass_hero/messaging/application/use_cases/get_inbound_email_test.exs
test/klass_hero/messaging/application/use_cases/reply_to_email_test.exs
test/klass_hero_web/controllers/resend_webhook_controller_test.exs
test/klass_hero_web/live/admin/emails_live_test.exs
test/support/fixtures/messaging_fixtures.ex
```

### Modified files

```
lib/klass_hero/messaging/repositories.ex          # Add inbound_emails/0 accessor + all/0 key
lib/klass_hero_web/router.ex                       # Add webhook route + admin email routes
lib/klass_hero_web/components/layouts/admin.html.heex  # Add Emails sidebar link
lib/klass_hero_web/endpoint.ex                         # Wire CacheRawBody as body_reader
config/test.exs                                        # Disable webhook signature verification in tests
```

---

## Task 1: Add Dependencies

**Files:**
- Modify: `mix.exs` (deps section, ~line 52-115)

- [ ] **Step 1: Add html_sanitize_ex and svix to deps**

In `mix.exs`, add to the `deps` list:

```elixir
{:html_sanitize_ex, "~> 1.4"},
{:svix, "~> 1.44"},
```

- [ ] **Step 2: Fetch deps**

Run: `mix deps.get`
Expected: Dependencies fetched successfully.

- [ ] **Step 3: Commit**

```bash
git add mix.exs mix.lock
git commit -m "chore: add html_sanitize_ex and svix dependencies"
```

---

## Task 2: Database Migration

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_create_inbound_emails.exs`

- [ ] **Step 1: Generate migration**

Run: `mix ecto.gen.migration create_inbound_emails`

- [ ] **Step 2: Write migration**

```elixir
defmodule KlassHero.Repo.Migrations.CreateInboundEmails do
  use Ecto.Migration

  def change do
    create table(:inbound_emails, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :resend_id, :string, null: false
      add :from_address, :string, null: false
      add :from_name, :string
      add :to_addresses, {:array, :string}, null: false, default: []
      add :cc_addresses, {:array, :string}, default: []
      add :subject, :string, null: false
      add :body_html, :text
      add :body_text, :text
      add :headers, {:array, :map}, null: false, default: []
      add :status, :string, null: false, default: "unread"
      add :read_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :read_at, :utc_datetime_usec
      add :received_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:inbound_emails, [:resend_id])
    create index(:inbound_emails, [:status])
    create index(:inbound_emails, [:received_at])
    create index(:inbound_emails, [:read_by_id])
  end
end
```

- [ ] **Step 3: Run migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully.

- [ ] **Step 4: Commit**

```bash
git add priv/repo/migrations/
git commit -m "feat: add inbound_emails table migration"
```

---

## Task 3: Domain Model

**Files:**
- Create: `lib/klass_hero/messaging/domain/models/inbound_email.ex`
- Create: `test/klass_hero/messaging/domain/models/inbound_email_test.exs`

- [ ] **Step 1: Write failing test for InboundEmail.new/1**

```elixir
defmodule KlassHero.Messaging.Domain.Models.InboundEmailTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.Models.InboundEmail

  @valid_attrs %{
    id: Ecto.UUID.generate(),
    resend_id: "resend_abc123",
    from_address: "sender@example.com",
    to_addresses: ["hello@klasshero.com"],
    subject: "Test Subject",
    received_at: DateTime.utc_now()
  }

  describe "new/1" do
    test "creates an inbound email with valid attributes" do
      assert {:ok, email} = InboundEmail.new(@valid_attrs)
      assert email.from_address == "sender@example.com"
      assert email.status == :unread
    end

    test "returns error for missing required fields" do
      assert {:error, errors} = InboundEmail.new(%{})
      assert is_list(errors)
      assert length(errors) > 0
    end

    test "returns error for invalid status" do
      attrs = Map.put(@valid_attrs, :status, :invalid)
      assert {:error, _} = InboundEmail.new(attrs)
    end
  end

  describe "mark_read/2" do
    test "transitions from unread to read" do
      {:ok, email} = InboundEmail.new(@valid_attrs)
      reader_id = Ecto.UUID.generate()
      {:ok, read_email} = InboundEmail.mark_read(email, reader_id)
      assert read_email.status == :read
      assert read_email.read_by_id == reader_id
      assert read_email.read_at != nil
    end

    test "is idempotent when already read" do
      {:ok, email} = InboundEmail.new(@valid_attrs)
      reader_id = Ecto.UUID.generate()
      {:ok, read_email} = InboundEmail.mark_read(email, reader_id)
      {:ok, same_email} = InboundEmail.mark_read(read_email, Ecto.UUID.generate())
      assert same_email.read_by_id == reader_id
    end
  end

  describe "archive/1" do
    test "transitions to archived" do
      {:ok, email} = InboundEmail.new(@valid_attrs)
      {:ok, archived} = InboundEmail.archive(email)
      assert archived.status == :archived
    end
  end

  describe "mark_unread/1" do
    test "transitions from read to unread" do
      {:ok, email} = InboundEmail.new(Map.put(@valid_attrs, :status, :read))
      {:ok, unread} = InboundEmail.mark_unread(email)
      assert unread.status == :unread
      assert unread.read_by_id == nil
      assert unread.read_at == nil
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/domain/models/inbound_email_test.exs`
Expected: FAIL — module `InboundEmail` not found.

- [ ] **Step 3: Implement InboundEmail domain model**

```elixir
defmodule KlassHero.Messaging.Domain.Models.InboundEmail do
  @moduledoc """
  Pure domain entity for an inbound email received via Resend webhook.

  Supports status transitions: unread → read → archived, and unread ← read.
  """

  @enforce_keys [:id, :resend_id, :from_address, :to_addresses, :subject, :received_at]

  defstruct [
    :id,
    :resend_id,
    :from_address,
    :from_name,
    :to_addresses,
    :cc_addresses,
    :subject,
    :body_html,
    :body_text,
    :headers,
    :read_by_id,
    :read_at,
    :received_at,
    :inserted_at,
    :updated_at,
    status: :unread
  ]

  @type status :: :unread | :read | :archived

  @type t :: %__MODULE__{
          id: String.t(),
          resend_id: String.t(),
          from_address: String.t(),
          from_name: String.t() | nil,
          to_addresses: [String.t()],
          cc_addresses: [String.t()] | nil,
          subject: String.t(),
          body_html: String.t() | nil,
          body_text: String.t() | nil,
          headers: [map()] | nil,
          status: status(),
          read_by_id: String.t() | nil,
          read_at: DateTime.t() | nil,
          received_at: DateTime.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @valid_statuses [:unread, :read, :archived]

  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) when is_map(attrs) do
    attrs = Map.put_new(attrs, :status, :unread)

    case build_struct(attrs) do
      {:ok, email} ->
        case validate(email) do
          [] -> {:ok, email}
          errors -> {:error, errors}
        end

      {:error, reason} ->
        {:error, [reason]}
    end
  end

  @spec mark_read(t(), String.t()) :: {:ok, t()}
  def mark_read(%__MODULE__{status: :read} = email, _reader_id), do: {:ok, email}

  def mark_read(%__MODULE__{} = email, reader_id) do
    {:ok, %{email | status: :read, read_by_id: reader_id, read_at: DateTime.utc_now()}}
  end

  @spec mark_unread(t()) :: {:ok, t()}
  def mark_unread(%__MODULE__{} = email) do
    {:ok, %{email | status: :unread, read_by_id: nil, read_at: nil}}
  end

  @spec archive(t()) :: {:ok, t()}
  def archive(%__MODULE__{} = email) do
    {:ok, %{email | status: :archived}}
  end

  @spec unread?(t()) :: boolean()
  def unread?(%__MODULE__{status: :unread}), do: true
  def unread?(%__MODULE__{}), do: false

  defp build_struct(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    ArgumentError -> {:error, "Missing required fields"}
  end

  defp validate(%__MODULE__{} = email) do
    []
    |> validate_uuid(:id, email.id)
    |> validate_present(:resend_id, email.resend_id)
    |> validate_present(:from_address, email.from_address)
    |> validate_present(:subject, email.subject)
    |> validate_list(:to_addresses, email.to_addresses)
    |> validate_status(email.status)
  end

  defp validate_uuid(errors, field, value) when is_binary(value) do
    if String.trim(value) == "",
      do: ["#{field} cannot be empty" | errors],
      else: errors
  end

  defp validate_uuid(errors, field, _), do: ["#{field} must be a string" | errors]

  defp validate_present(errors, field, value) when is_binary(value) do
    if String.trim(value) == "",
      do: ["#{field} cannot be empty" | errors],
      else: errors
  end

  defp validate_present(errors, field, _), do: ["#{field} must be a string" | errors]

  defp validate_list(errors, _field, value) when is_list(value) and length(value) > 0, do: errors
  defp validate_list(errors, field, _), do: ["#{field} must be a non-empty list" | errors]

  defp validate_status(errors, status) when status in @valid_statuses, do: errors

  defp validate_status(errors, _) do
    valid = @valid_statuses |> Enum.map_join(", ", &to_string/1)
    ["status must be one of: #{valid}" | errors]
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/domain/models/inbound_email_test.exs`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/domain/models/inbound_email.ex test/klass_hero/messaging/domain/models/inbound_email_test.exs
git commit -m "feat: add InboundEmail domain model with status transitions"
```

---

## Task 4: Port, Schema, Mapper, Queries

**Files:**
- Create: `lib/klass_hero/messaging/domain/ports/for_managing_inbound_emails.ex`
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/inbound_email_schema.ex`
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/mappers/inbound_email_mapper.ex`
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/queries/inbound_email_queries.ex`

- [ ] **Step 1: Create the port behaviour**

Follow `ForManagingMessages` pattern. Callbacks needed:
- `create(attrs)` → `{:ok, InboundEmail.t()} | {:error, term()}`
- `get_by_id(id)` → `{:ok, InboundEmail.t()} | {:error, :not_found}`
- `get_by_resend_id(resend_id)` → `{:ok, InboundEmail.t()} | {:error, :not_found}`
- `list(opts)` → `{:ok, [InboundEmail.t()], has_more :: boolean()}`
- `update_status(id, status, attrs)` → `{:ok, InboundEmail.t()} | {:error, term()}`
- `count_by_status(status)` → non_neg_integer()

```elixir
defmodule KlassHero.Messaging.Domain.Ports.ForManagingInboundEmails do
  @moduledoc """
  Repository port for managing inbound emails in the Messaging bounded context.
  """

  alias KlassHero.Messaging.Domain.Models.InboundEmail

  @callback create(attrs :: map()) ::
              {:ok, InboundEmail.t()} | {:error, term()}

  @callback get_by_id(id :: binary()) ::
              {:ok, InboundEmail.t()} | {:error, :not_found}

  @callback get_by_resend_id(resend_id :: String.t()) ::
              {:ok, InboundEmail.t()} | {:error, :not_found}

  @doc """
  Lists inbound emails with pagination and filtering.

  Options:
  - limit: integer (default 50)
  - status: :unread | :read | :archived | nil (all)
  - before: DateTime (cursor pagination)
  """
  @callback list(opts :: keyword()) ::
              {:ok, [InboundEmail.t()], has_more :: boolean()}

  @callback update_status(id :: binary(), status :: String.t(), attrs :: map()) ::
              {:ok, InboundEmail.t()} | {:error, term()}

  @callback count_by_status(status :: atom()) :: non_neg_integer()
end
```

- [ ] **Step 2: Create the Ecto schema**

Follow `MessageSchema` pattern — `@primary_key {:id, :binary_id, autogenerate: true}`, `@timestamps_opts [type: :utc_datetime]`.

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.InboundEmailSchema do
  @moduledoc """
  Ecto schema for the inbound_emails table.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias KlassHero.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(unread read archived)

  schema "inbound_emails" do
    field :resend_id, :string
    field :from_address, :string
    field :from_name, :string
    field :to_addresses, {:array, :string}, default: []
    field :cc_addresses, {:array, :string}, default: []
    field :subject, :string
    field :body_html, :string
    field :body_text, :string
    field :headers, {:array, :map}, default: []
    field :status, :string, default: "unread"
    field :read_by_id, :binary_id
    field :read_at, :utc_datetime_usec
    field :received_at, :utc_datetime_usec

    belongs_to :read_by, User, foreign_key: :read_by_id, define_field: false

    timestamps()
  end

  @required_fields ~w(resend_id from_address to_addresses subject received_at)a
  @optional_fields ~w(from_name cc_addresses body_html body_text headers status)a

  def create_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:resend_id)
    |> foreign_key_constraint(:read_by_id)
  end

  def status_changeset(schema, attrs) do
    schema
    |> cast(attrs, [:status, :read_by_id, :read_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
  end
end
```

- [ ] **Step 3: Create the mapper**

Follow `MessageMapper` pattern.

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.InboundEmailMapper do
  @moduledoc """
  Maps between InboundEmailSchema (Ecto) and InboundEmail (domain model).
  """

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.InboundEmailSchema
  alias KlassHero.Messaging.Domain.Models.InboundEmail

  @spec to_domain(InboundEmailSchema.t()) :: InboundEmail.t()
  def to_domain(%InboundEmailSchema{} = schema) do
    %InboundEmail{
      id: schema.id,
      resend_id: schema.resend_id,
      from_address: schema.from_address,
      from_name: schema.from_name,
      to_addresses: schema.to_addresses,
      cc_addresses: schema.cc_addresses,
      subject: schema.subject,
      body_html: schema.body_html,
      body_text: schema.body_text,
      headers: schema.headers,
      status: String.to_existing_atom(schema.status),
      read_by_id: schema.read_by_id,
      read_at: schema.read_at,
      received_at: schema.received_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @spec to_create_attrs(map()) :: map()
  def to_create_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.take([
      :resend_id, :from_address, :from_name, :to_addresses, :cc_addresses,
      :subject, :body_html, :body_text, :headers, :received_at
    ])
    |> Map.put_new(:status, "unread")
  end
end
```

- [ ] **Step 4: Create the queries module**

Follow `MessageQueries` pattern — composable query builders.

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Queries.InboundEmailQueries do
  @moduledoc """
  Composable Ecto query builders for inbound emails.
  """

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.InboundEmailSchema

  def base do
    from(e in InboundEmailSchema, as: :inbound_email)
  end

  def by_id(query, id) do
    where(query, [inbound_email: e], e.id == ^id)
  end

  def by_resend_id(query, resend_id) do
    where(query, [inbound_email: e], e.resend_id == ^resend_id)
  end

  def by_status(query, nil), do: query

  def by_status(query, status) do
    status_string = to_string(status)
    where(query, [inbound_email: e], e.status == ^status_string)
  end

  def order_by_newest(query) do
    order_by(query, [inbound_email: e], desc: e.received_at, desc: e.id)
  end

  def paginate(query, opts) do
    limit = Keyword.get(opts, :limit, 50)
    before_ts = Keyword.get(opts, :before)

    query
    |> before(before_ts)
    |> limit(^(limit + 1))
  end

  def before(query, nil), do: query

  def before(query, timestamp) do
    where(query, [inbound_email: e], e.received_at < ^timestamp)
  end

  def count_by_status(status) do
    status_string = to_string(status)

    base()
    |> where([inbound_email: e], e.status == ^status_string)
    |> select([inbound_email: e], count(e.id))
  end
end
```

- [ ] **Step 5: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/messaging/domain/ports/for_managing_inbound_emails.ex \
        lib/klass_hero/messaging/adapters/driven/persistence/schemas/inbound_email_schema.ex \
        lib/klass_hero/messaging/adapters/driven/persistence/mappers/inbound_email_mapper.ex \
        lib/klass_hero/messaging/adapters/driven/persistence/queries/inbound_email_queries.ex
git commit -m "feat: add inbound email port, schema, mapper, and queries"
```

---

## Task 5: Repository Adapter + Config Wiring

**Files:**
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/repositories/inbound_email_repository.ex`
- Create: `test/klass_hero/messaging/adapters/driven/persistence/repositories/inbound_email_repository_test.exs`
- Create: `test/support/fixtures/messaging_fixtures.ex`
- Modify: `lib/klass_hero/messaging/repositories.ex`
- Modify: `config/config.exs` (~line 130-145)

- [ ] **Step 1: Write failing repository test**

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepository
  alias KlassHero.MessagingFixtures

  describe "create/1" do
    test "inserts an inbound email and returns domain model" do
      attrs = MessagingFixtures.valid_inbound_email_attrs()
      assert {:ok, email} = InboundEmailRepository.create(attrs)
      assert email.resend_id == attrs.resend_id
      assert email.status == :unread
    end

    test "rejects duplicate resend_id" do
      attrs = MessagingFixtures.valid_inbound_email_attrs()
      assert {:ok, _} = InboundEmailRepository.create(attrs)
      assert {:error, _} = InboundEmailRepository.create(attrs)
    end
  end

  describe "get_by_id/1" do
    test "returns email when found" do
      email = MessagingFixtures.inbound_email_fixture()
      assert {:ok, found} = InboundEmailRepository.get_by_id(email.id)
      assert found.id == email.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} = InboundEmailRepository.get_by_id(Ecto.UUID.generate())
    end
  end

  describe "get_by_resend_id/1" do
    test "returns email when found" do
      email = MessagingFixtures.inbound_email_fixture()
      assert {:ok, found} = InboundEmailRepository.get_by_resend_id(email.resend_id)
      assert found.id == email.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} = InboundEmailRepository.get_by_resend_id("nonexistent")
    end
  end

  describe "list/1" do
    test "returns emails ordered by received_at desc" do
      e1 = MessagingFixtures.inbound_email_fixture(%{received_at: ~U[2026-01-01 10:00:00Z]})
      e2 = MessagingFixtures.inbound_email_fixture(%{received_at: ~U[2026-01-02 10:00:00Z]})

      assert {:ok, emails, false} = InboundEmailRepository.list([])
      assert [first | _] = emails
      assert first.id == e2.id
    end

    test "filters by status" do
      _unread = MessagingFixtures.inbound_email_fixture(%{status: "unread"})
      read = MessagingFixtures.inbound_email_fixture(%{status: "read"})

      assert {:ok, emails, false} = InboundEmailRepository.list(status: :read)
      assert length(emails) == 1
      assert hd(emails).id == read.id
    end
  end

  describe "update_status/3" do
    test "updates status to read" do
      email = MessagingFixtures.inbound_email_fixture()
      reader_id = KlassHero.AccountsFixtures.user_fixture().id

      assert {:ok, updated} =
               InboundEmailRepository.update_status(email.id, "read", %{
                 read_by_id: reader_id,
                 read_at: DateTime.utc_now()
               })

      assert updated.status == :read
      assert updated.read_by_id == reader_id
    end
  end

  describe "count_by_status/1" do
    test "counts emails by status" do
      MessagingFixtures.inbound_email_fixture(%{status: "unread"})
      MessagingFixtures.inbound_email_fixture(%{status: "unread"})
      MessagingFixtures.inbound_email_fixture(%{status: "read"})

      assert InboundEmailRepository.count_by_status(:unread) == 2
      assert InboundEmailRepository.count_by_status(:read) == 1
    end
  end
end
```

- [ ] **Step 2: Create MessagingFixtures**

```elixir
defmodule KlassHero.MessagingFixtures do
  @moduledoc """
  Test fixtures for the Messaging bounded context.
  """

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepository

  def unique_resend_id, do: "resend_#{System.unique_integer([:positive])}"

  def valid_inbound_email_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      resend_id: unique_resend_id(),
      from_address: "sender#{System.unique_integer([:positive])}@example.com",
      to_addresses: ["hello@klasshero.com"],
      subject: "Test Email #{System.unique_integer([:positive])}",
      body_html: "<p>Hello</p>",
      body_text: "Hello",
      headers: [],
      received_at: DateTime.utc_now()
    })
  end

  def inbound_email_fixture(attrs \\ %{}) do
    {:ok, email} =
      attrs
      |> valid_inbound_email_attrs()
      |> InboundEmailRepository.create()

    email
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/adapters/driven/persistence/repositories/inbound_email_repository_test.exs`
Expected: FAIL — `InboundEmailRepository` not found.

- [ ] **Step 4: Implement InboundEmailRepository**

Follow `MessageRepository` pattern.

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepository do
  @moduledoc """
  Ecto-based repository for managing inbound emails.

  Implements ForManagingInboundEmails port.
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForManagingInboundEmails

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.InboundEmailMapper
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Queries.InboundEmailQueries
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.InboundEmailSchema
  alias KlassHero.Repo

  require Logger

  @impl true
  def create(attrs) do
    schema_attrs = InboundEmailMapper.to_create_attrs(attrs)

    %InboundEmailSchema{}
    |> InboundEmailSchema.create_changeset(schema_attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        email = InboundEmailMapper.to_domain(schema)
        Logger.info("Stored inbound email", resend_id: email.resend_id, from: email.from_address)
        {:ok, email}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @impl true
  def get_by_id(id) do
    InboundEmailQueries.base()
    |> InboundEmailQueries.by_id(id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> {:ok, InboundEmailMapper.to_domain(schema)}
    end
  end

  @impl true
  def get_by_resend_id(resend_id) do
    InboundEmailQueries.base()
    |> InboundEmailQueries.by_resend_id(resend_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> {:ok, InboundEmailMapper.to_domain(schema)}
    end
  end

  @impl true
  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status = Keyword.get(opts, :status)

    results =
      InboundEmailQueries.base()
      |> InboundEmailQueries.by_status(status)
      |> InboundEmailQueries.order_by_newest()
      |> InboundEmailQueries.paginate(opts)
      |> Repo.all()

    has_more = length(results) > limit
    emails = results |> Enum.take(limit) |> Enum.map(&InboundEmailMapper.to_domain/1)

    {:ok, emails, has_more}
  end

  @impl true
  def update_status(id, status, attrs) do
    InboundEmailSchema
    |> Repo.get(id)
    |> case do
      nil ->
        {:error, :not_found}

      schema ->
        update_attrs = Map.merge(attrs, %{status: status})

        schema
        |> InboundEmailSchema.status_changeset(update_attrs)
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            Logger.debug("Updated inbound email status",
              id: id,
              status: status
            )

            {:ok, InboundEmailMapper.to_domain(updated)}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @impl true
  def count_by_status(status) do
    InboundEmailQueries.count_by_status(status)
    |> Repo.one()
    |> Kernel.||(0)
  end
end
```

- [ ] **Step 5: Wire up Repositories module and config**

Modify `lib/klass_hero/messaging/repositories.ex`:
- Add `:inbound_emails` key to `all/0` map and `@spec`
- Add `inbound_emails/0` accessor function

Modify `config/config.exs` (~line 130):
- Add `for_managing_inbound_emails: KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepository` to the `:messaging` config

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/klass_hero/messaging/adapters/driven/persistence/repositories/inbound_email_repository_test.exs`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/messaging/adapters/driven/persistence/repositories/inbound_email_repository.ex \
        lib/klass_hero/messaging/repositories.ex \
        config/config.exs \
        test/klass_hero/messaging/adapters/driven/persistence/repositories/inbound_email_repository_test.exs \
        test/support/fixtures/messaging_fixtures.ex
git commit -m "feat: add InboundEmailRepository with config wiring"
```

---

## Task 6: Email Sanitizer

**Files:**
- Create: `lib/klass_hero/messaging/adapters/driven/email_sanitizer.ex`
- Create: `test/klass_hero/messaging/adapters/driven/email_sanitizer_test.exs`

- [ ] **Step 1: Write failing sanitizer test**

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.EmailSanitizerTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Adapters.Driven.EmailSanitizer

  describe "sanitize/1" do
    test "preserves safe HTML tags" do
      html = "<p>Hello <strong>world</strong></p>"
      assert EmailSanitizer.sanitize(html) =~ "<p>"
      assert EmailSanitizer.sanitize(html) =~ "<strong>"
    end

    test "strips script tags" do
      html = "<p>Hello</p><script>alert('xss')</script>"
      result = EmailSanitizer.sanitize(html)
      refute result =~ "<script>"
      assert result =~ "<p>Hello</p>"
    end

    test "strips iframe tags" do
      html = "<p>Hello</p><iframe src=\"evil.com\"></iframe>"
      result = EmailSanitizer.sanitize(html)
      refute result =~ "<iframe>"
    end

    test "strips event handler attributes" do
      html = "<p onclick=\"alert('xss')\">Hello</p>"
      result = EmailSanitizer.sanitize(html)
      refute result =~ "onclick"
    end

    test "replaces external images with placeholder" do
      html = "<img src=\"https://tracker.com/pixel.gif\">"
      result = EmailSanitizer.sanitize(html)
      refute result =~ "https://tracker.com"
    end

    test "adds target=_blank to links" do
      html = "<a href=\"https://example.com\">Link</a>"
      result = EmailSanitizer.sanitize(html)
      assert result =~ "target=\"_blank\""
      assert result =~ "rel=\"noopener noreferrer\""
    end

    test "returns empty string for nil input" do
      assert EmailSanitizer.sanitize(nil) == ""
    end

    test "preserves table elements" do
      html = "<table><tr><td>Cell</td></tr></table>"
      result = EmailSanitizer.sanitize(html)
      assert result =~ "<table>"
      assert result =~ "<td>"
    end
  end

  describe "sanitize/2 with allow_images: true" do
    test "preserves external images when allowed" do
      html = "<img src=\"https://example.com/photo.jpg\">"
      result = EmailSanitizer.sanitize(html, allow_images: true)
      assert result =~ "https://example.com/photo.jpg"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/adapters/driven/email_sanitizer_test.exs`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement EmailSanitizer**

Uses `html_sanitize_ex` with a custom scrubber. The scrubber defines allowed tags, attributes, and link rewriting rules.

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.EmailSanitizer do
  @moduledoc """
  Sanitizes inbound email HTML for safe rendering in the admin panel.

  Strips dangerous tags and attributes, blocks external images by default,
  and adds safety attributes to links.
  """

  @spec sanitize(String.t() | nil) :: String.t()
  def sanitize(html), do: sanitize(html, [])

  @spec sanitize(String.t() | nil, keyword()) :: String.t()
  def sanitize(nil, _opts), do: ""
  def sanitize("", _opts), do: ""

  def sanitize(html, opts) when is_binary(html) do
    allow_images = Keyword.get(opts, :allow_images, false)

    html
    |> HtmlSanitizeEx.basic_html()
    |> post_process_links()
    |> maybe_handle_images(allow_images)
  end

  defp post_process_links(html) do
    # Add target="_blank" and rel="noopener noreferrer" to all links
    String.replace(html, ~r/<a\s/, "<a target=\"_blank\" rel=\"noopener noreferrer\" ")
  end

  defp maybe_handle_images(html, true), do: html

  defp maybe_handle_images(html, false) do
    # Replace img tags with external sources
    String.replace(html, ~r/<img[^>]*src="https?:\/\/[^"]*"[^>]*>/i, "[image blocked]")
  end
end
```

Note: The exact implementation may need adjustment based on `html_sanitize_ex`'s API. Check `mix usage_rules.docs HtmlSanitizeEx` at implementation time and adapt.

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/adapters/driven/email_sanitizer_test.exs`
Expected: All tests PASS. Adjust implementation if needed based on actual `html_sanitize_ex` behaviour.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/adapters/driven/email_sanitizer.ex \
        test/klass_hero/messaging/adapters/driven/email_sanitizer_test.exs
git commit -m "feat: add EmailSanitizer for safe HTML rendering"
```

---

## Task 7: Use Cases (Receive, List, Get, Reply)

**Files:**
- Create: `lib/klass_hero/messaging/application/use_cases/receive_inbound_email.ex`
- Create: `lib/klass_hero/messaging/application/use_cases/list_inbound_emails.ex`
- Create: `lib/klass_hero/messaging/application/use_cases/get_inbound_email.ex`
- Create: `lib/klass_hero/messaging/application/use_cases/reply_to_email.ex`
- Create: `test/klass_hero/messaging/application/use_cases/receive_inbound_email_test.exs`
- Create: `test/klass_hero/messaging/application/use_cases/list_inbound_emails_test.exs`
- Create: `test/klass_hero/messaging/application/use_cases/get_inbound_email_test.exs`
- Create: `test/klass_hero/messaging/application/use_cases/reply_to_email_test.exs`

Each use case follows the `SendMessage` pattern: `@spec execute(args) :: {:ok, result} | {:error, reason}`, uses `Repositories.all()`, `with` for chaining, decision-point comments.

### Sub-task 7a: ReceiveInboundEmail

- [ ] **Step 1: Write failing test**

Test that `execute/1` with valid Resend payload creates an inbound email, and with duplicate `resend_id` returns `{:ok, :duplicate}`.

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement**

Core logic: check dedup by `resend_id` → if exists, return `{:ok, :duplicate}` → otherwise `repo.create(attrs)`.

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Commit**

### Sub-task 7b: ListInboundEmails

- [ ] **Step 1: Write failing test**

Test `execute/1` returns paginated list with filters (status, limit).

- [ ] **Step 2: Run, verify fails**

- [ ] **Step 3: Implement**

Delegates to `repo.list(opts)`.

- [ ] **Step 4: Run, verify passes**

- [ ] **Step 5: Commit**

### Sub-task 7c: GetInboundEmail

- [ ] **Step 1: Write failing test**

Test `execute/2` returns email and marks as read when `mark_read: true` option with `reader_id` passed.

- [ ] **Step 2: Run, verify fails**

- [ ] **Step 3: Implement**

Fetches by ID, optionally calls `update_status` to mark read.

- [ ] **Step 4: Run, verify passes**

- [ ] **Step 5: Commit**

### Sub-task 7d: ReplyToEmail

- [ ] **Step 1: Write failing test**

Test `execute/3` builds and delivers a Swoosh email with correct `In-Reply-To` header. Use `Swoosh.Adapters.Test` and `Swoosh.TestAssertions`.

- [ ] **Step 2: Run, verify fails**

- [ ] **Step 3: Implement**

Builds `Swoosh.Email` with from (shared address from config), to (original sender), subject (Re: original), body, `In-Reply-To`/`References` headers extracted from stored headers array.

```elixir
defp extract_message_id(headers) when is_list(headers) do
  Enum.find_value(headers, fn
    %{"name" => "Message-ID", "value" => value} -> value
    %{"name" => "message-id", "value" => value} -> value
    _ -> nil
  end)
end

defp extract_message_id(_), do: nil
```

- [ ] **Step 4: Run, verify passes**

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/application/use_cases/receive_inbound_email.ex \
        lib/klass_hero/messaging/application/use_cases/list_inbound_emails.ex \
        lib/klass_hero/messaging/application/use_cases/get_inbound_email.ex \
        lib/klass_hero/messaging/application/use_cases/reply_to_email.ex \
        test/klass_hero/messaging/application/use_cases/
git commit -m "feat: add use cases for inbound email receive, list, get, reply"
```

---

## Task 8: Webhook Controller

**Files:**
- Create: `lib/klass_hero_web/plugs/cache_raw_body.ex`
- Create: `lib/klass_hero_web/controllers/resend_webhook_controller.ex`
- Create: `test/klass_hero_web/controllers/resend_webhook_controller_test.exs`
- Modify: `lib/klass_hero_web/router.ex`
- Modify: `config/runtime.exs`

- [ ] **Step 1: Write failing controller test**

```elixir
defmodule KlassHeroWeb.ResendWebhookControllerTest do
  use KlassHeroWeb.ConnCase, async: true

  alias KlassHero.MessagingFixtures

  @valid_payload %{
    "type" => "email.received",
    "data" => %{
      "email_id" => "resend_test_123",
      "from" => "sender@example.com",
      "to" => ["hello@klasshero.com"],
      "subject" => "Test Email",
      "html" => "<p>Hello</p>",
      "text" => "Hello",
      "headers" => [%{"name" => "Message-ID", "value" => "<abc@example.com>"}],
      "created_at" => "2026-03-20T10:00:00Z"
    }
  }

  describe "POST /webhooks/resend" do
    test "returns 200 for valid email.received event", %{conn: conn} do
      conn = post(conn, ~p"/webhooks/resend", @valid_payload)
      assert json_response(conn, 200)
    end

    test "returns 200 for duplicate (idempotent)", %{conn: conn} do
      post(conn, ~p"/webhooks/resend", @valid_payload)
      conn2 = post(conn, ~p"/webhooks/resend", @valid_payload)
      assert json_response(conn2, 200)
    end

    test "returns 200 for unhandled event types", %{conn: conn} do
      payload = %{"type" => "email.delivered", "data" => %{}}
      conn = post(conn, ~p"/webhooks/resend", payload)
      assert json_response(conn, 200)
    end
  end
end
```

Note: In test environment, skip Svix signature verification (configure via application env). Production uses real verification.

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero_web/controllers/resend_webhook_controller_test.exs`
Expected: FAIL — route/controller not found.

- [ ] **Step 3: Create CacheRawBody plug**

```elixir
defmodule KlassHeroWeb.Plugs.CacheRawBody do
  @moduledoc """
  Caches the raw request body for webhook signature verification.

  Must be used as a custom body reader for Plug.Parsers.
  Stores the raw body in conn.assigns[:raw_body].
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = Plug.Conn.assign(conn, :raw_body, body)
    {:ok, body, conn}
  end
end
```

- [ ] **Step 4: Wire CacheRawBody into endpoint**

Modify `lib/klass_hero_web/endpoint.ex` — update the existing `Plug.Parsers` config to use the custom body reader. Only webhook paths need the raw body cached, so scope it:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  body_reader: {KlassHeroWeb.Plugs.CacheRawBody, :read_body, []},
  json_decoder: Phoenix.json_library()
```

Note: This caches raw body for ALL requests. Acceptable trade-off for simplicity — the raw body is a small overhead. If performance becomes a concern, scope to webhook paths only.

- [ ] **Step 5: Add webhook route to router**

In `router.ex`, add before the catch-all routes:

```elixir
scope "/webhooks", KlassHeroWeb do
  pipe_through :api

  post "/resend", ResendWebhookController, :handle
end
```

- [ ] **Step 6: Implement ResendWebhookController**

```elixir
defmodule KlassHeroWeb.ResendWebhookController do
  use KlassHeroWeb, :controller

  alias KlassHero.Messaging.Application.UseCases.ReceiveInboundEmail

  require Logger

  def handle(conn, %{"type" => "email.received", "data" => data}) do
    attrs = %{
      resend_id: data["email_id"],
      from_address: data["from"],
      from_name: data["from_name"],
      to_addresses: data["to"] || [],
      cc_addresses: data["cc"] || [],
      subject: data["subject"] || "(no subject)",
      body_html: data["html"],
      body_text: data["text"],
      headers: data["headers"] || [],
      received_at: parse_timestamp(data["created_at"])
    }

    case ReceiveInboundEmail.execute(attrs) do
      {:ok, _email} ->
        json(conn, %{status: "ok"})

      {:ok, :duplicate} ->
        json(conn, %{status: "ok", note: "duplicate"})

      {:error, reason} ->
        Logger.error("Failed to process inbound email",
          resend_id: data["email_id"],
          reason: inspect(reason)
        )

        json(conn, %{status: "ok"})
    end
  end

  # Trigger: Resend sends events other than email.received (delivered, bounced, etc.)
  # Why: we only care about received emails; returning 200 prevents Resend retries
  # Outcome: event is acknowledged but not processed
  def handle(conn, %{"type" => type}) do
    Logger.debug("Ignoring Resend webhook event", type: type)
    json(conn, %{status: "ok"})
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(timestamp_string) do
    case DateTime.from_iso8601(timestamp_string) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> DateTime.utc_now()
    end
  end
end
```

- [ ] **Step 7: Add RESEND_WEBHOOK_SECRET to runtime.exs**

Add after the existing Resend config (~line 64):

```elixir
config :klass_hero, :resend_webhook_secret,
  System.get_env("RESEND_WEBHOOK_SECRET")
```

- [ ] **Step 8: Add Svix signature verification plug/check**

Add signature verification to the controller (skip in test env). Use `Svix.Webhook.verify/3`. The implementer should check `mix usage_rules.docs Svix.Webhook` for exact API. Configure test env to skip verification via `config :klass_hero, :verify_webhook_signature, false` in `config/test.exs`.

- [ ] **Step 9: Run test to verify it passes**

Run: `mix test test/klass_hero_web/controllers/resend_webhook_controller_test.exs`
Expected: All tests PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/klass_hero_web/plugs/cache_raw_body.ex \
        lib/klass_hero_web/controllers/resend_webhook_controller.ex \
        lib/klass_hero_web/router.ex \
        lib/klass_hero_web/endpoint.ex \
        config/runtime.exs \
        config/test.exs \
        test/klass_hero_web/controllers/resend_webhook_controller_test.exs
git commit -m "feat: add Resend webhook controller with signature verification"
```

---

## Task 9: Admin LiveView — Inbox + Detail + Reply

**Files:**
- Create: `lib/klass_hero_web/live/admin/emails_live.ex`
- Create: `test/klass_hero_web/live/admin/emails_live_test.exs`
- Modify: `lib/klass_hero_web/router.ex`
- Modify: `lib/klass_hero_web/components/layouts/admin.html.heex`

- [ ] **Step 1: Write failing LiveView test — index**

```elixir
defmodule KlassHeroWeb.Admin.EmailsLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.MessagingFixtures

  setup :register_and_log_in_admin

  describe "Index" do
    test "lists inbound emails", %{conn: conn} do
      email = MessagingFixtures.inbound_email_fixture(%{subject: "Hello Admin"})
      {:ok, view, _html} = live(conn, ~p"/admin/emails")
      assert has_element?(view, "#emails-table")
      assert render(view) =~ "Hello Admin"
    end

    test "filters by status", %{conn: conn} do
      MessagingFixtures.inbound_email_fixture(%{status: "unread", subject: "Unread One"})
      MessagingFixtures.inbound_email_fixture(%{status: "read", subject: "Read One"})

      {:ok, view, _html} = live(conn, ~p"/admin/emails")
      assert render(view) =~ "Unread One"
      assert render(view) =~ "Read One"

      view |> element("#filter-unread") |> render_click()
      assert render(view) =~ "Unread One"
      refute render(view) =~ "Read One"
    end
  end

  describe "Show" do
    test "displays email detail with sanitized HTML", %{conn: conn} do
      email = MessagingFixtures.inbound_email_fixture(%{
        subject: "Important Message",
        body_html: "<p>Hello <strong>world</strong></p><script>evil()</script>"
      })

      {:ok, view, html} = live(conn, ~p"/admin/emails/#{email.id}")
      assert html =~ "Important Message"
      assert html =~ "<strong>world</strong>"
      refute html =~ "<script>"
    end

    test "shows reply form", %{conn: conn} do
      email = MessagingFixtures.inbound_email_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/emails/#{email.id}")
      assert has_element?(view, "#reply-form")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Add admin email routes**

In `router.ex`, inside the `:admin_custom` live_session (~line 167), add:

```elixir
live "/emails", EmailsLive, :index
live "/emails/:id", EmailsLive, :show
```

- [ ] **Step 4: Implement EmailsLive**

Follow `SessionsLive` pattern: `mount/3` (must assign `fluid?: false` and `live_resource: nil` for admin layout compatibility), `handle_params/3` with `apply_action/3`, streams for email list, `handle_event/3` for filter clicks / reply submit / archive / mark unread.

Key points:
- `:index` action: stream emails, track filter state, unread count badge
- `:show` action: fetch email, mark as read, sanitize HTML with `EmailSanitizer.sanitize/2`, reply form with `to_form/2`
- Reply submit: call `ReplyToEmail.execute/3`, flash success, stay on page
- Archive/mark unread: call `GetInboundEmail` use case or repository, update status

Template uses admin layout classes. Render sanitized HTML with `raw/1`. "Load images" toggle re-renders with `allow_images: true`.

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero_web/live/admin/emails_live_test.exs`
Expected: All tests PASS.

- [ ] **Step 6: Add sidebar link**

In `admin.html.heex`, add before the Sessions sidebar item (~line 48). Include unread count badge — the count is loaded via `on_mount` hook or a shared assign helper that queries `InboundEmailRepository.count_by_status(:unread)`.

```heex
<Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate={~p"/admin/emails"}>
  <Backpex.HTML.CoreComponents.icon name="hero-envelope" class="h-5 w-5" /> {gettext("Emails")}
  <span :if={assigns[:unread_email_count] && @unread_email_count > 0}
    class="ml-auto inline-flex items-center justify-center rounded-full bg-red-500 px-2 py-0.5 text-xs font-bold text-white">
    {@unread_email_count}
  </span>
</Backpex.HTML.Layout.sidebar_item>
```

The `@unread_email_count` assign should be set in the `mount/3` of `EmailsLive` and also via the admin layout's `on_mount` hook so it's available on all admin pages. The simplest approach: load it in `EmailsLive.mount/3` and accept it being absent on other admin pages (the `:if` guard handles this).

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/live/admin/emails_live.ex \
        lib/klass_hero_web/router.ex \
        lib/klass_hero_web/components/layouts/admin.html.heex \
        test/klass_hero_web/live/admin/emails_live_test.exs
git commit -m "feat: add admin emails LiveView with inbox, detail, and reply"
```

---

## Task 10: Final Integration + Precommit

- [ ] **Step 1: Run full test suite**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 2: Run precommit**

Run: `mix precommit`
Expected: Compiles with no warnings, formats cleanly, all tests pass.

- [ ] **Step 3: Fix any issues found**

Address warnings, formatting, or test failures.

- [ ] **Step 4: Final commit if needed**

```bash
git commit -m "chore: fix precommit issues"
```

---

## Execution Notes

- **TDD discipline**: Every task follows red-green-refactor. Write the test, watch it fail, implement minimal code, watch it pass.
- **Idiomatic Elixir**: Pattern match on function heads, use `with` for chaining fallible operations, tagged tuples for returns, pipe operator for transformations. Pure domain structs, behaviours for ports.
- **Check docs at implementation time**: Run `mix usage_rules.docs HtmlSanitizeEx` and `mix usage_rules.docs Svix.Webhook` to verify exact API before implementing sanitizer and signature verification. The code in this plan is based on expected APIs — adjust as needed.
- **Tidewave MCP**: Use for evaluating Elixir, checking docs, running SQL queries during implementation.
