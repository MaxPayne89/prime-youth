# Photo Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **REQUIRED SKILLS:** Use `idiomatic-elixir` skill when writing any `.ex` or `.exs` file.
>
> **TIDEWAVE MCP — MANDATORY:** Use Tidewave MCP tools extensively throughout implementation:
> - `get_docs` / `search_package_docs` — look up Ecto, Phoenix, LiveView APIs before writing code
> - `project_eval` — test domain model validation, evaluate expressions, verify module behavior
> - `execute_sql_query` — verify migrations, check table structure, test queries
> - `get_source_location` — find existing patterns to follow
> - `get_ecto_schemas` — inspect schema definitions
> - `get_logs` — check for warnings/errors after running code
>
> If Tidewave is unavailable, alert the user immediately.
>
> **TDD WORKFLOW — MANDATORY:** For every feature, follow Red-Green-Refactor:
> 1. Write the failing test first
> 2. Run it to verify it fails for the right reason
> 3. Write the minimal implementation to make it pass
> 4. Run tests to verify they pass
> 5. Refactor if needed
> 6. Commit

**Goal:** Add photo attachment support to the messaging system — users can attach up to 5 images per message, stored in S3, flowing through the event-driven architecture.

**Architecture:** Attachments are a child entity of the Message aggregate, persisted in their own table. The `SendMessage` use case orchestrates S3 uploads via the existing `ForStoringFiles` port and DB persistence via a new `ForManagingAttachments` port. The enriched `message_sent` event flows through domain → integration → projection to update the ConversationSummaries read model.

**Tech Stack:** Elixir 1.20, Phoenix 1.8, LiveView 1.1, Ecto, PostgreSQL, ExAws.S3

**Spec:** `docs/superpowers/specs/2026-04-04-photo-attachments-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/klass_hero/messaging/domain/models/attachment.ex` | Pure domain struct + validation |
| `lib/klass_hero/messaging/domain/ports/for_managing_attachments.ex` | Driven port behaviour |
| `lib/klass_hero/messaging/adapters/driven/persistence/schemas/attachment_schema.ex` | Ecto schema |
| `lib/klass_hero/messaging/adapters/driven/persistence/mappers/attachment_mapper.ex` | Schema <-> domain mapping |
| `lib/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository.ex` | Port implementation |
| `priv/repo/migrations/TIMESTAMP_create_message_attachments.exs` | DB table |
| `priv/repo/migrations/TIMESTAMP_add_has_attachments_to_conversation_summaries.exs` | Read model column |
| `test/klass_hero/messaging/domain/models/attachment_test.exs` | Domain model tests |
| `test/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository_test.exs` | Repository tests |

### Modified Files

| File | Change |
|------|--------|
| `lib/klass_hero/messaging/domain/models/message.ex` | Optional content, attachments field |
| `lib/klass_hero/messaging/adapters/driven/persistence/schemas/message_schema.ex` | has_many, nullable content |
| `lib/klass_hero/messaging/adapters/driven/persistence/mappers/message_mapper.ex` | Map attachments |
| `lib/klass_hero/messaging/application/use_cases/send_message.ex` | S3 upload orchestration |
| `lib/klass_hero/messaging/domain/events/messaging_events.ex` | Enriched payload |
| `lib/klass_hero/messaging/domain/events/messaging_integration_events.ex` | Version bump, attachments |
| `lib/klass_hero/messaging/adapters/driving/events/event_handlers/promote_integration_events.ex` | Forward attachments |
| `lib/klass_hero/messaging/adapters/driving/events/event_handlers/notify_live_views.ex` | Forward attachments |
| `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex` | has_attachments projection |
| `lib/klass_hero/messaging/adapters/driven/persistence/schemas/conversation_summary_schema.ex` | New field |
| `lib/klass_hero/messaging/application/use_cases/enforce_retention_policy.ex` | S3 cleanup |
| `lib/klass_hero/messaging.ex` | Boundary export, facade update |
| `config/config.exs` | DI wiring |
| `lib/klass_hero_web/live/messaging_live_helper.ex` | Upload handling |
| `lib/klass_hero_web/components/messaging_components.ex` | Photo rendering |
| `test/klass_hero/messaging/domain/models/message_test.exs` | New test cases |
| `test/klass_hero/messaging/application/use_cases/send_message_test.exs` | New test cases |
| `test/support/fixtures/messaging_fixtures.ex` | Attachment fixtures |

---

## Task 1: Attachment Domain Model (TDD)

**Files:**
- Create: `lib/klass_hero/messaging/domain/models/attachment.ex`
- Create: `test/klass_hero/messaging/domain/models/attachment_test.exs`

- [ ] **Step 1: Explore existing patterns with Tidewave**

Use Tidewave to understand the existing Message model pattern:

```
get_source_location(reference: "KlassHero.Messaging.Domain.Models.Message")
get_docs(reference: "Ecto.UUID.generate/0")
```

- [ ] **Step 2: Write the failing test**

Create `test/klass_hero/messaging/domain/models/attachment_test.exs`:

```elixir
defmodule KlassHero.Messaging.Domain.Models.AttachmentTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.Models.Attachment

  describe "new/1" do
    test "creates attachment with valid attributes" do
      attrs = valid_attrs()

      assert {:ok, attachment} = Attachment.new(attrs)
      assert attachment.id == attrs.id
      assert attachment.message_id == attrs.message_id
      assert attachment.file_url == attrs.file_url
      assert attachment.original_filename == "photo.jpg"
      assert attachment.content_type == "image/jpeg"
      assert attachment.file_size_bytes == 2_400_000
    end

    test "accepts all allowed image content types" do
      for content_type <- ~w(image/jpeg image/png image/gif image/webp) do
        attrs = valid_attrs(%{content_type: content_type})
        assert {:ok, _} = Attachment.new(attrs), "expected #{content_type} to be valid"
      end
    end

    test "rejects unsupported content type" do
      attrs = valid_attrs(%{content_type: "application/pdf"})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "content_type"))
    end

    test "rejects file exceeding 10 MB" do
      attrs = valid_attrs(%{file_size_bytes: 10_485_761})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "file_size_bytes"))
    end

    test "accepts file at exactly 10 MB" do
      attrs = valid_attrs(%{file_size_bytes: 10_485_760})

      assert {:ok, _} = Attachment.new(attrs)
    end

    test "rejects zero file size" do
      attrs = valid_attrs(%{file_size_bytes: 0})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "file_size_bytes"))
    end

    test "rejects missing required fields" do
      assert {:error, ["Missing required fields"]} = Attachment.new(%{})
    end

    test "rejects empty file_url" do
      attrs = valid_attrs(%{file_url: ""})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "file_url"))
    end

    test "rejects empty original_filename" do
      attrs = valid_attrs(%{original_filename: ""})

      assert {:error, errors} = Attachment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "original_filename"))
    end
  end

  describe "allowed_content_types/0" do
    test "returns list of image MIME types" do
      types = Attachment.allowed_content_types()

      assert "image/jpeg" in types
      assert "image/png" in types
      assert "image/gif" in types
      assert "image/webp" in types
    end
  end

  describe "max_file_size_bytes/0" do
    test "returns 10 MB in bytes" do
      assert Attachment.max_file_size_bytes() == 10_485_760
    end
  end

  describe "max_per_message/0" do
    test "returns 5" do
      assert Attachment.max_per_message() == 5
    end
  end

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        id: Ecto.UUID.generate(),
        message_id: Ecto.UUID.generate(),
        file_url: "https://s3.example.com/messaging/attachments/#{Ecto.UUID.generate()}/photo.jpg",
        original_filename: "photo.jpg",
        content_type: "image/jpeg",
        file_size_bytes: 2_400_000
      },
      overrides
    )
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/domain/models/attachment_test.exs`
Expected: Compilation error — `Attachment` module does not exist.

- [ ] **Step 4: Write minimal implementation**

Create `lib/klass_hero/messaging/domain/models/attachment.ex`:

```elixir
defmodule KlassHero.Messaging.Domain.Models.Attachment do
  @moduledoc """
  Pure domain entity representing a file attachment on a message.

  Currently restricted to image types. The allowed content types list
  can be extended to support other file types in the future.
  """

  @enforce_keys [:id, :message_id, :file_url, :original_filename, :content_type, :file_size_bytes]

  defstruct [
    :id,
    :message_id,
    :file_url,
    :original_filename,
    :content_type,
    :file_size_bytes,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          message_id: String.t(),
          file_url: String.t(),
          original_filename: String.t(),
          content_type: String.t(),
          file_size_bytes: pos_integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @allowed_content_types ~w(image/jpeg image/png image/gif image/webp)
  @max_file_size_bytes 10_485_760
  @max_per_message 5

  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) when is_map(attrs) do
    case build_struct(attrs) do
      {:ok, attachment} ->
        case validate(attachment) do
          [] -> {:ok, attachment}
          errors -> {:error, errors}
        end

      {:error, reason} ->
        {:error, [reason]}
    end
  end

  @spec allowed_content_types() :: [String.t()]
  def allowed_content_types, do: @allowed_content_types

  @spec max_file_size_bytes() :: pos_integer()
  def max_file_size_bytes, do: @max_file_size_bytes

  @spec max_per_message() :: pos_integer()
  def max_per_message, do: @max_per_message

  defp build_struct(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    ArgumentError -> {:error, "Missing required fields"}
  end

  defp validate(%__MODULE__{} = attachment) do
    []
    |> validate_non_empty_string(:file_url, attachment.file_url)
    |> validate_non_empty_string(:original_filename, attachment.original_filename)
    |> validate_content_type(attachment.content_type)
    |> validate_file_size(attachment.file_size_bytes)
  end

  defp validate_non_empty_string(errors, field, value) when is_binary(value) do
    if String.trim(value) == "" do
      ["#{field} cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_non_empty_string(errors, field, _), do: ["#{field} must be a string" | errors]

  defp validate_content_type(errors, type) when type in @allowed_content_types, do: errors

  defp validate_content_type(errors, _type) do
    allowed = Enum.join(@allowed_content_types, ", ")
    ["content_type must be one of: #{allowed}" | errors]
  end

  defp validate_file_size(errors, size) when is_integer(size) and size > 0 and size <= @max_file_size_bytes do
    errors
  end

  defp validate_file_size(errors, _size) do
    ["file_size_bytes must be between 1 and #{@max_file_size_bytes}" | errors]
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/domain/models/attachment_test.exs`
Expected: All tests PASS.

- [ ] **Step 6: Verify interactively with Tidewave**

```
project_eval(code: """
  alias KlassHero.Messaging.Domain.Models.Attachment
  Attachment.new(%{
    id: Ecto.UUID.generate(),
    message_id: Ecto.UUID.generate(),
    file_url: "https://example.com/photo.jpg",
    original_filename: "photo.jpg",
    content_type: "image/jpeg",
    file_size_bytes: 1_000_000
  })
""")
```

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/messaging/domain/models/attachment.ex test/klass_hero/messaging/domain/models/attachment_test.exs
git commit -m "feat: add Attachment domain model with validation"
```

---

## Task 2: Message Model Changes (TDD)

**Files:**
- Modify: `lib/klass_hero/messaging/domain/models/message.ex`
- Modify: `test/klass_hero/messaging/domain/models/message_test.exs`

- [ ] **Step 1: Write failing tests**

Add to `test/klass_hero/messaging/domain/models/message_test.exs` inside the `describe "new/1"` block:

```elixir
test "allows nil content when attachments are present" do
  attachment = %KlassHero.Messaging.Domain.Models.Attachment{
    id: Ecto.UUID.generate(),
    message_id: Ecto.UUID.generate(),
    file_url: "https://example.com/photo.jpg",
    original_filename: "photo.jpg",
    content_type: "image/jpeg",
    file_size_bytes: 1_000_000
  }

  attrs = %{
    id: Ecto.UUID.generate(),
    conversation_id: Ecto.UUID.generate(),
    sender_id: Ecto.UUID.generate(),
    content: nil,
    attachments: [attachment]
  }

  assert {:ok, message} = Message.new(attrs)
  assert message.content == nil
  assert length(message.attachments) == 1
end

test "returns error when both content and attachments are empty" do
  attrs = %{
    id: Ecto.UUID.generate(),
    conversation_id: Ecto.UUID.generate(),
    sender_id: Ecto.UUID.generate(),
    content: nil,
    attachments: []
  }

  assert {:error, errors} = Message.new(attrs)
  assert "message must have content or attachments" in errors
end

test "allows content with attachments" do
  attachment = %KlassHero.Messaging.Domain.Models.Attachment{
    id: Ecto.UUID.generate(),
    message_id: Ecto.UUID.generate(),
    file_url: "https://example.com/photo.jpg",
    original_filename: "photo.jpg",
    content_type: "image/jpeg",
    file_size_bytes: 1_000_000
  }

  attrs = %{
    id: Ecto.UUID.generate(),
    conversation_id: Ecto.UUID.generate(),
    sender_id: Ecto.UUID.generate(),
    content: "Check out this photo!",
    attachments: [attachment]
  }

  assert {:ok, message} = Message.new(attrs)
  assert message.content == "Check out this photo!"
  assert length(message.attachments) == 1
end

test "rejects more than 5 attachments" do
  attachments =
    for _ <- 1..6 do
      %KlassHero.Messaging.Domain.Models.Attachment{
        id: Ecto.UUID.generate(),
        message_id: Ecto.UUID.generate(),
        file_url: "https://example.com/photo.jpg",
        original_filename: "photo.jpg",
        content_type: "image/jpeg",
        file_size_bytes: 1_000_000
      }
    end

  attrs = %{
    id: Ecto.UUID.generate(),
    conversation_id: Ecto.UUID.generate(),
    sender_id: Ecto.UUID.generate(),
    content: nil,
    attachments: attachments
  }

  assert {:error, errors} = Message.new(attrs)
  assert Enum.any?(errors, &String.contains?(&1, "attachments"))
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/messaging/domain/models/message_test.exs`
Expected: New tests FAIL (content is still required, attachments field doesn't exist).

- [ ] **Step 3: Update Message model**

In `lib/klass_hero/messaging/domain/models/message.ex`:

1. Remove `:content` from `@enforce_keys` (now optional)
2. Add `attachments: []` to `defstruct`
3. Update `@type t` to include `attachments: [Attachment.t()]` and `content: String.t() | nil`
4. Replace `validate_content/2` to allow nil when attachments are present
5. Add `validate_attachments_count/2`
6. In `new/1`, default `attachments` to `[]`

Key changes to validation logic:

```elixir
# Replace validate_content with:
defp validate_content(errors, content, attachments) when is_binary(content) do
  trimmed = String.trim(content)

  cond do
    trimmed == "" and attachments == [] ->
      ["message must have content or attachments" | errors]

    trimmed == "" ->
      # Empty content is OK when attachments are present
      errors

    String.length(content) > @max_content_length ->
      ["content cannot exceed #{@max_content_length} characters" | errors]

    true ->
      errors
  end
end

defp validate_content(errors, nil, []) do
  ["message must have content or attachments" | errors]
end

defp validate_content(errors, nil, _attachments), do: errors

defp validate_content(errors, _, _), do: ["content must be a string or nil" | errors]
```

Add attachments count validation:

```elixir
defp validate_attachments_count(errors, attachments) when length(attachments) > @max_attachments do
  ["attachments cannot exceed #{@max_attachments} per message" | errors]
end

defp validate_attachments_count(errors, _), do: errors
```

Where `@max_attachments 5` is a new module attribute.

Also add `alias KlassHero.Messaging.Domain.Models.Attachment` at the top.

- [ ] **Step 4: Run tests to verify all pass**

Run: `mix test test/klass_hero/messaging/domain/models/message_test.exs`
Expected: All tests PASS (including existing ones — backward compatible).

- [ ] **Step 5: Verify with Tidewave**

```
project_eval(code: """
  alias KlassHero.Messaging.Domain.Models.{Message, Attachment}
  # Photo-only message
  Message.new(%{
    id: Ecto.UUID.generate(),
    conversation_id: Ecto.UUID.generate(),
    sender_id: Ecto.UUID.generate(),
    content: nil,
    attachments: [%Attachment{
      id: Ecto.UUID.generate(), message_id: Ecto.UUID.generate(),
      file_url: "https://x.com/p.jpg", original_filename: "p.jpg",
      content_type: "image/jpeg", file_size_bytes: 1000
    }]
  })
""")
```

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/messaging/domain/models/message.ex test/klass_hero/messaging/domain/models/message_test.exs
git commit -m "feat: make message content optional when attachments present"
```

---

## Task 3: Database Migrations

**Files:**
- Create: `priv/repo/migrations/*_create_message_attachments.exs`
- Create: `priv/repo/migrations/*_add_has_attachments_to_conversation_summaries.exs`

- [ ] **Step 1: Check existing migration patterns with Tidewave**

```
get_docs(reference: "Ecto.Migration")
execute_sql_query(query: "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'messages' ORDER BY ordinal_position")
```

- [ ] **Step 2: Create message_attachments migration**

Run: `mix ecto.gen.migration create_message_attachments`

Replace contents with:

```elixir
defmodule KlassHero.Repo.Migrations.CreateMessageAttachments do
  use Ecto.Migration

  def change do
    create table(:message_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :file_url, :text, null: false
      add :original_filename, :string, size: 255, null: false
      add :content_type, :string, size: 100, null: false
      add :file_size_bytes, :bigint, null: false

      timestamps()
    end

    create index(:message_attachments, [:message_id])
  end
end
```

- [ ] **Step 3: Create conversation_summaries migration**

Run: `mix ecto.gen.migration add_has_attachments_to_conversation_summaries`

Replace contents with:

```elixir
defmodule KlassHero.Repo.Migrations.AddHasAttachmentsToConversationSummaries do
  use Ecto.Migration

  def change do
    alter table(:conversation_summaries) do
      add :has_attachments, :boolean, default: false, null: false
    end
  end
end
```

- [ ] **Step 4: Run migrations**

Run: `mix ecto.migrate`
Expected: Both migrations succeed.

- [ ] **Step 5: Verify with Tidewave**

```
execute_sql_query(query: "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'message_attachments' ORDER BY ordinal_position")
execute_sql_query(query: "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'conversation_summaries' AND column_name = 'has_attachments'")
```

- [ ] **Step 6: Commit**

```bash
git add priv/repo/migrations/
git commit -m "feat: create message_attachments table and add has_attachments to summaries"
```

---

## Task 4: Ecto Schema, Mapper, and MessageSchema Update

**Files:**
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/attachment_schema.ex`
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/mappers/attachment_mapper.ex`
- Modify: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/message_schema.ex`
- Modify: `lib/klass_hero/messaging/adapters/driven/persistence/mappers/message_mapper.ex`

- [ ] **Step 1: Examine existing schema patterns with Tidewave**

```
get_source_location(reference: "KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.MessageSchema")
get_ecto_schemas()
```

- [ ] **Step 2: Create AttachmentSchema**

Create `lib/klass_hero/messaging/adapters/driven/persistence/schemas/attachment_schema.ex`:

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.AttachmentSchema do
  @moduledoc """
  Ecto schema for message attachments.

  Attachments are immutable — once created, they are never updated.
  Deletion is handled by ON DELETE CASCADE from the messages table.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.MessageSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "message_attachments" do
    field :file_url, :string
    field :original_filename, :string
    field :content_type, :string
    field :file_size_bytes, :integer

    belongs_to :message, MessageSchema

    timestamps()
  end

  @required_fields ~w(message_id file_url original_filename content_type file_size_bytes)a

  @doc "Changeset for creating a new attachment."
  def create_changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:message_id)
  end
end
```

- [ ] **Step 3: Create AttachmentMapper**

Create `lib/klass_hero/messaging/adapters/driven/persistence/mappers/attachment_mapper.ex`:

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.AttachmentMapper do
  @moduledoc """
  Maps between AttachmentSchema (Ecto) and Attachment (domain model).
  """

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.AttachmentSchema
  alias KlassHero.Messaging.Domain.Models.Attachment

  @spec to_domain(AttachmentSchema.t()) :: Attachment.t()
  def to_domain(%AttachmentSchema{} = schema) do
    %Attachment{
      id: schema.id,
      message_id: schema.message_id,
      file_url: schema.file_url,
      original_filename: schema.original_filename,
      content_type: schema.content_type,
      file_size_bytes: schema.file_size_bytes,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @spec to_create_attrs(map()) :: map()
  def to_create_attrs(attrs) when is_map(attrs) do
    Map.take(attrs, [:message_id, :file_url, :original_filename, :content_type, :file_size_bytes])
  end
end
```

- [ ] **Step 4: Update MessageSchema — add has_many and make content nullable**

In `lib/klass_hero/messaging/adapters/driven/persistence/schemas/message_schema.ex`:

Add below the existing `belongs_to` associations:

```elixir
has_many :attachments, KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.AttachmentSchema
```

In the `create_changeset/2`, remove `:content` from `validate_required` (content is now optional). The field stays in `cast` but is no longer required.

- [ ] **Step 5: Update MessageMapper — handle attachments**

In `lib/klass_hero/messaging/adapters/driven/persistence/mappers/message_mapper.ex`:

Add alias at top:

```elixir
alias KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.AttachmentMapper
alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.AttachmentSchema
```

Update `to_domain/1` to map preloaded attachments:

```elixir
def to_domain(%MessageSchema{} = schema) do
  %Message{
    id: schema.id,
    conversation_id: schema.conversation_id,
    sender_id: schema.sender_id,
    content: schema.content,
    message_type: String.to_existing_atom(schema.message_type),
    deleted_at: schema.deleted_at,
    inserted_at: schema.inserted_at,
    updated_at: schema.updated_at,
    attachments: map_attachments(schema.attachments)
  }
end

defp map_attachments(%Ecto.Association.NotLoaded{}), do: []
defp map_attachments(nil), do: []
defp map_attachments(attachments), do: Enum.map(attachments, &AttachmentMapper.to_domain/1)
```

- [ ] **Step 6: Verify with Tidewave**

```
project_eval(code: """
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.AttachmentSchema
  AttachmentSchema.__schema__(:fields)
""")
```

- [ ] **Step 7: Run full test suite to ensure no regressions**

Run: `mix test test/klass_hero/messaging/`
Expected: All existing tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/klass_hero/messaging/adapters/driven/persistence/schemas/attachment_schema.ex \
        lib/klass_hero/messaging/adapters/driven/persistence/mappers/attachment_mapper.ex \
        lib/klass_hero/messaging/adapters/driven/persistence/schemas/message_schema.ex \
        lib/klass_hero/messaging/adapters/driven/persistence/mappers/message_mapper.ex
git commit -m "feat: add AttachmentSchema, AttachmentMapper, update MessageSchema"
```

---

## Task 5: Port Contract and DI Wiring

**Files:**
- Create: `lib/klass_hero/messaging/domain/ports/for_managing_attachments.ex`
- Modify: `config/config.exs`
- Modify: `lib/klass_hero/messaging.ex`

- [ ] **Step 1: Create ForManagingAttachments port**

Create `lib/klass_hero/messaging/domain/ports/for_managing_attachments.ex`:

```elixir
defmodule KlassHero.Messaging.Domain.Ports.ForManagingAttachments do
  @moduledoc """
  Repository port for managing message attachments.

  Attachments are child entities of Messages — they have no independent
  lifecycle. Creation is always in the context of a message, and deletion
  is handled by DB cascade (ON DELETE CASCADE from messages table).
  """

  alias KlassHero.Messaging.Domain.Models.Attachment

  @doc """
  Bulk-inserts attachments for a message.

  All attachments must belong to the same message.
  """
  @callback create_many([map()]) :: {:ok, [Attachment.t()]} | {:error, term()}

  @doc """
  Lists attachments for a single message.
  """
  @callback list_for_message(message_id :: String.t()) :: [Attachment.t()]

  @doc """
  Batch-fetches attachments for multiple messages.

  Returns a map of message_id => [attachments]. Messages with no
  attachments are omitted from the map.
  """
  @callback list_for_messages([message_id :: String.t()]) :: %{String.t() => [Attachment.t()]}

  @doc """
  Queries file URLs for attachments belonging to the given conversations.

  Used by the retention policy to collect S3 URLs for cleanup before
  hard-deleting messages (which cascade-deletes attachment records).

  Does NOT delete records — the caller handles that via message deletion.
  """
  @callback get_urls_for_conversations([conversation_id :: String.t()]) :: {:ok, [String.t()]}
end
```

- [ ] **Step 2: Wire DI in config**

In `config/config.exs`, add to the messaging config block (after the existing `for_scheduling_email_jobs` line, before `retention:`):

```elixir
for_managing_attachments: AttachmentRepository,
```

Add the alias at the top of config.exs where other messaging aliases are:

```elixir
alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.AttachmentRepository
```

- [ ] **Step 3: Update Boundary exports**

In `lib/klass_hero/messaging.ex`, add to exports:

```elixir
Domain.Models.Attachment,
```

- [ ] **Step 4: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles with warnings (AttachmentRepository doesn't exist yet — that's OK, it's wired but not implemented). If it fails due to missing module at compile time, temporarily comment out the config line and proceed to Task 6.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/domain/ports/for_managing_attachments.ex \
        config/config.exs \
        lib/klass_hero/messaging.ex
git commit -m "feat: add ForManagingAttachments port, wire DI, update boundary exports"
```

---

## Task 6: Attachment Repository (TDD)

**Files:**
- Create: `lib/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository.ex`
- Create: `test/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository_test.exs`
- Modify: `test/support/fixtures/messaging_fixtures.ex`

- [ ] **Step 1: Look up existing repository patterns with Tidewave**

```
get_source_location(reference: "KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.MessageRepository")
get_docs(reference: "Ecto.Repo.insert_all/3")
```

- [ ] **Step 2: Add attachment fixture helper**

In `test/support/fixtures/messaging_fixtures.ex`, add:

```elixir
alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.AttachmentSchema

def attachment_fixture(message_id, attrs \\ %{}) do
  defaults = %{
    message_id: message_id,
    file_url: "https://s3.example.com/messaging/attachments/#{Ecto.UUID.generate()}/photo.jpg",
    original_filename: "test_photo.jpg",
    content_type: "image/jpeg",
    file_size_bytes: 2_400_000
  }

  {:ok, attachment} =
    defaults
    |> Map.merge(attrs)
    |> then(&AttachmentSchema.create_changeset(%AttachmentSchema{}, &1))
    |> KlassHero.Repo.insert()

  attachment
end
```

- [ ] **Step 3: Write failing repository tests**

Create `test/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository_test.exs`:

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.AttachmentRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory
  import KlassHero.MessagingFixtures

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.AttachmentRepository
  alias KlassHero.Messaging.Domain.Models.Attachment

  describe "create_many/1" do
    test "inserts multiple attachments for a message" do
      conversation = insert(:conversation_schema)
      user = KlassHero.AccountsFixtures.user_fixture()
      message = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)

      attrs_list = [
        %{
          message_id: message.id,
          file_url: "https://s3.example.com/photo1.jpg",
          original_filename: "photo1.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 1_000_000
        },
        %{
          message_id: message.id,
          file_url: "https://s3.example.com/photo2.png",
          original_filename: "photo2.png",
          content_type: "image/png",
          file_size_bytes: 2_000_000
        }
      ]

      assert {:ok, attachments} = AttachmentRepository.create_many(attrs_list)
      assert length(attachments) == 2
      assert Enum.all?(attachments, &match?(%Attachment{}, &1))
      assert Enum.all?(attachments, &(&1.message_id == message.id))
    end

    test "returns ok with empty list for no attachments" do
      assert {:ok, []} = AttachmentRepository.create_many([])
    end
  end

  describe "list_for_message/1" do
    test "returns attachments for a message" do
      conversation = insert(:conversation_schema)
      user = KlassHero.AccountsFixtures.user_fixture()
      message = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)

      attachment_fixture(message.id, %{original_filename: "photo1.jpg"})
      attachment_fixture(message.id, %{original_filename: "photo2.jpg"})

      attachments = AttachmentRepository.list_for_message(message.id)
      assert length(attachments) == 2
      assert Enum.all?(attachments, &match?(%Attachment{}, &1))
    end

    test "returns empty list when no attachments exist" do
      assert [] == AttachmentRepository.list_for_message(Ecto.UUID.generate())
    end
  end

  describe "list_for_messages/1" do
    test "returns map of message_id to attachments" do
      conversation = insert(:conversation_schema)
      user = KlassHero.AccountsFixtures.user_fixture()
      msg1 = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)
      msg2 = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)
      msg3 = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)

      attachment_fixture(msg1.id)
      attachment_fixture(msg1.id)
      attachment_fixture(msg2.id)
      # msg3 has no attachments

      result = AttachmentRepository.list_for_messages([msg1.id, msg2.id, msg3.id])

      assert length(result[msg1.id]) == 2
      assert length(result[msg2.id]) == 1
      refute Map.has_key?(result, msg3.id)
    end

    test "returns empty map for empty input" do
      assert %{} == AttachmentRepository.list_for_messages([])
    end
  end

  describe "get_urls_for_conversations/1" do
    test "returns file URLs for conversation attachments" do
      conversation = insert(:conversation_schema)
      user = KlassHero.AccountsFixtures.user_fixture()
      message = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)

      a1 = attachment_fixture(message.id, %{file_url: "https://s3.example.com/url1.jpg"})
      a2 = attachment_fixture(message.id, %{file_url: "https://s3.example.com/url2.jpg"})

      assert {:ok, urls} = AttachmentRepository.get_urls_for_conversations([conversation.id])
      assert length(urls) == 2
      assert a1.file_url in urls
      assert a2.file_url in urls
    end

    test "returns empty list when no attachments" do
      assert {:ok, []} = AttachmentRepository.get_urls_for_conversations([Ecto.UUID.generate()])
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `mix test test/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository_test.exs`
Expected: FAIL — `AttachmentRepository` module does not exist.

- [ ] **Step 5: Implement AttachmentRepository**

Create `lib/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository.ex`:

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.AttachmentRepository do
  @moduledoc """
  Ecto implementation of ForManagingAttachments port.
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForManagingAttachments

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.AttachmentMapper
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.AttachmentSchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.MessageSchema
  alias KlassHero.Repo

  use KlassHero.Shared.Tracing

  @impl true
  def create_many([]), do: {:ok, []}

  def create_many(attrs_list) do
    span do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      entries =
        Enum.map(attrs_list, fn attrs ->
          attrs
          |> AttachmentMapper.to_create_attrs()
          |> Map.put(:id, Ecto.UUID.generate())
          |> Map.put(:inserted_at, now)
          |> Map.put(:updated_at, now)
        end)

      {_count, schemas} =
        Repo.insert_all(AttachmentSchema, entries, returning: true)

      {:ok, Enum.map(schemas, &AttachmentMapper.to_domain/1)}
    end
  end

  @impl true
  def list_for_message(message_id) do
    span do
      AttachmentSchema
      |> where([a], a.message_id == ^message_id)
      |> order_by([a], asc: a.inserted_at)
      |> Repo.all()
      |> Enum.map(&AttachmentMapper.to_domain/1)
    end
  end

  @impl true
  def list_for_messages([]), do: %{}

  def list_for_messages(message_ids) do
    span do
      AttachmentSchema
      |> where([a], a.message_id in ^message_ids)
      |> order_by([a], asc: a.inserted_at)
      |> Repo.all()
      |> Enum.map(&AttachmentMapper.to_domain/1)
      |> Enum.group_by(& &1.message_id)
    end
  end

  @impl true
  def get_urls_for_conversations([]), do: {:ok, []}

  def get_urls_for_conversations(conversation_ids) do
    span do
      urls =
        AttachmentSchema
        |> join(:inner, [a], m in MessageSchema, on: a.message_id == m.id)
        |> where([_a, m], m.conversation_id in ^conversation_ids)
        |> select([a, _m], a.file_url)
        |> Repo.all()

      {:ok, urls}
    end
  end
end
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository_test.exs`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository.ex \
        test/klass_hero/messaging/adapters/driven/persistence/repositories/attachment_repository_test.exs \
        test/support/fixtures/messaging_fixtures.ex
git commit -m "feat: implement AttachmentRepository with TDD"
```

---

## Task 7: Domain and Integration Events Update

**Files:**
- Modify: `lib/klass_hero/messaging/domain/events/messaging_events.ex`
- Modify: `lib/klass_hero/messaging/domain/events/messaging_integration_events.ex`

- [ ] **Step 1: Update domain event factory**

In `lib/klass_hero/messaging/domain/events/messaging_events.ex`, update `message_sent/6` to accept attachments:

Change signature to `message_sent/7` with optional attachments parameter:

```elixir
def message_sent(conversation_id, message_id, sender_id, content, message_type, sent_at \\ nil, attachments \\ []) do
  DomainEvent.new(
    :message_sent,
    conversation_id,
    @aggregate_type,
    %{
      conversation_id: conversation_id,
      message_id: message_id,
      sender_id: sender_id,
      content: content,
      message_type: message_type,
      sent_at: sent_at || DateTime.utc_now(),
      attachments: Enum.map(attachments, &serialize_attachment/1)
    }
  )
end

defp serialize_attachment(%{id: id, file_url: url, original_filename: name, content_type: ct, file_size_bytes: size}) do
  %{id: id, file_url: url, original_filename: name, content_type: ct, file_size_bytes: size}
end
```

Update the `@spec` accordingly.

- [ ] **Step 2: Update integration event factory**

In `lib/klass_hero/messaging/domain/events/messaging_integration_events.ex`:

Update the `@type message_sent_payload` to include optional attachments:

```elixir
@typedoc "Payload for `:message_sent` events."
@type message_sent_payload :: %{
        required(:conversation_id) => String.t(),
        required(:sender_id) => String.t(),
        required(:content) => String.t() | nil,
        optional(:message_type) => String.t() | nil,
        optional(:sent_at) => DateTime.t() | nil,
        optional(:attachments) => [map()],
        optional(atom()) => term()
      }
```

In the `message_sent/3` pattern match, also allow `nil` content:

```elixir
def message_sent(conversation_id, %{sender_id: _} = payload, opts)
    when is_binary(conversation_id) and byte_size(conversation_id) > 0 do
```

Remove the `content: _` from the required pattern match (content is now optional in payload).

Update the missing keys check to only require `:sender_id`:

```elixir
def message_sent(conversation_id, payload, _opts)
    when is_binary(conversation_id) and byte_size(conversation_id) > 0 do
  missing = [:sender_id] -- Map.keys(payload)
  ...
end
```

- [ ] **Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: No warnings.

- [ ] **Step 4: Run messaging tests**

Run: `mix test test/klass_hero/messaging/`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/domain/events/messaging_events.ex \
        lib/klass_hero/messaging/domain/events/messaging_integration_events.ex
git commit -m "feat: enrich message_sent event with attachment metadata"
```

---

## Task 8: SendMessage Use Case Update (TDD)

**Files:**
- Modify: `lib/klass_hero/messaging/application/use_cases/send_message.ex`
- Modify: `test/klass_hero/messaging/application/use_cases/send_message_test.exs`

- [ ] **Step 1: Look up Storage API with Tidewave**

```
get_source_location(reference: "KlassHero.Shared.Storage")
get_docs(reference: "KlassHero.Shared.Storage.upload/4")
```

- [ ] **Step 2: Write failing tests**

Add to `test/klass_hero/messaging/application/use_cases/send_message_test.exs`:

```elixir
describe "execute/4 with attachments" do
  test "sends message with text and attachments" do
    conversation = insert(:conversation_schema)
    user = AccountsFixtures.user_fixture()
    insert(:participant_schema, conversation_id: conversation.id, user_id: user.id)

    file_data = [
      %{binary: "fake-image-bytes", filename: "photo.jpg", content_type: "image/jpeg", size: 1_000}
    ]

    assert {:ok, message} =
             SendMessage.execute(conversation.id, user.id, "Check this out!", attachments: file_data)

    assert message.content == "Check this out!"
    assert length(message.attachments) == 1
    assert hd(message.attachments).original_filename == "photo.jpg"
  end

  test "sends photo-only message (nil content)" do
    conversation = insert(:conversation_schema)
    user = AccountsFixtures.user_fixture()
    insert(:participant_schema, conversation_id: conversation.id, user_id: user.id)

    file_data = [
      %{binary: "fake-image-bytes", filename: "photo.jpg", content_type: "image/jpeg", size: 1_000}
    ]

    assert {:ok, message} =
             SendMessage.execute(conversation.id, user.id, nil, attachments: file_data)

    assert message.content == nil
    assert length(message.attachments) == 1
  end

  test "rejects empty message — no content and no attachments" do
    conversation = insert(:conversation_schema)
    user = AccountsFixtures.user_fixture()
    insert(:participant_schema, conversation_id: conversation.id, user_id: user.id)

    assert {:error, :empty_message} =
             SendMessage.execute(conversation.id, user.id, nil, attachments: [])
  end

  test "rejects invalid attachment content type" do
    conversation = insert(:conversation_schema)
    user = AccountsFixtures.user_fixture()
    insert(:participant_schema, conversation_id: conversation.id, user_id: user.id)

    file_data = [
      %{binary: "fake-bytes", filename: "doc.pdf", content_type: "application/pdf", size: 1_000}
    ]

    assert {:error, :invalid_attachments} =
             SendMessage.execute(conversation.id, user.id, nil, attachments: file_data)
  end

  test "rejects oversized attachment" do
    conversation = insert(:conversation_schema)
    user = AccountsFixtures.user_fixture()
    insert(:participant_schema, conversation_id: conversation.id, user_id: user.id)

    file_data = [
      %{binary: "fake-bytes", filename: "huge.jpg", content_type: "image/jpeg", size: 11_000_000}
    ]

    assert {:error, :invalid_attachments} =
             SendMessage.execute(conversation.id, user.id, nil, attachments: file_data)
  end

  test "rejects more than 5 attachments" do
    conversation = insert(:conversation_schema)
    user = AccountsFixtures.user_fixture()
    insert(:participant_schema, conversation_id: conversation.id, user_id: user.id)

    file_data =
      for i <- 1..6 do
        %{binary: "fake-bytes", filename: "photo#{i}.jpg", content_type: "image/jpeg", size: 1_000}
      end

    assert {:error, :invalid_attachments} =
             SendMessage.execute(conversation.id, user.id, nil, attachments: file_data)
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `mix test test/klass_hero/messaging/application/use_cases/send_message_test.exs --max-failures 3`
Expected: New tests FAIL.

- [ ] **Step 4: Update SendMessage use case**

In `lib/klass_hero/messaging/application/use_cases/send_message.ex`:

Add new aliases and module attributes:

```elixir
alias KlassHero.Messaging.Domain.Models.Attachment
alias KlassHero.Shared.Storage

@attachment_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_attachments])
```

Update `execute/4`:

```elixir
def execute(conversation_id, sender_id, content, opts \\ []) do
  message_type = Keyword.get(opts, :message_type, :text)
  conversation = Keyword.get(opts, :conversation)
  raw_attachments = Keyword.get(opts, :attachments, [])
  content = if is_binary(content), do: String.trim(content), else: content

  with :ok <- validate_message_content(content, raw_attachments),
       :ok <- validate_attachment_files(raw_attachments),
       :ok <- Shared.verify_participant(conversation_id, sender_id, @participant_repo),
       :ok <- verify_broadcast_send_permission(conversation_id, sender_id, conversation),
       {:ok, uploaded_files} <- upload_files(conversation_id, raw_attachments),
       {:ok, message} <- persist_message_and_attachments(conversation_id, sender_id, content, message_type, uploaded_files) do
    update_sender_read_status(conversation_id, sender_id)
    publish_event(message)

    Logger.info("Message sent",
      message_id: message.id,
      conversation_id: conversation_id,
      sender_id: sender_id,
      attachment_count: length(message.attachments)
    )

    {:ok, message}
  end
end

defp validate_message_content(nil, []), do: {:error, :empty_message}
defp validate_message_content(content, []) when is_binary(content) and byte_size(content) == 0, do: {:error, :empty_message}
defp validate_message_content(_, _), do: :ok

defp validate_attachment_files([]), do: :ok

defp validate_attachment_files(files) do
  cond do
    length(files) > Attachment.max_per_message() ->
      {:error, :invalid_attachments}

    Enum.any?(files, fn f -> f.content_type not in Attachment.allowed_content_types() end) ->
      {:error, :invalid_attachments}

    Enum.any?(files, fn f -> f.size > Attachment.max_file_size_bytes() end) ->
      {:error, :invalid_attachments}

    true ->
      :ok
  end
end

defp upload_files(_conversation_id, []), do: {:ok, []}

defp upload_files(conversation_id, files) do
  message_id = Ecto.UUID.generate()

  files
  |> Enum.reduce_while({:ok, [], message_id}, fn file, {:ok, acc, mid} ->
    file_id = Ecto.UUID.generate()
    ext = Path.extname(file.filename)
    path = "messaging/attachments/#{mid}/#{file_id}#{ext}"

    case Storage.upload(:public, path, file.binary, content_type: file.content_type) do
      {:ok, url} ->
        uploaded = %{
          url: url,
          path: path,
          original_filename: file.filename,
          content_type: file.content_type,
          file_size_bytes: file.size
        }

        {:cont, {:ok, [uploaded | acc], mid}}

      {:error, _reason} ->
        cleanup_uploaded_files(acc)
        {:halt, {:error, :upload_failed}}
    end
  end)
  |> case do
    {:ok, uploaded, message_id} -> {:ok, {Enum.reverse(uploaded), message_id}}
    error -> error
  end
end

defp persist_message_and_attachments(conversation_id, sender_id, content, message_type, {uploaded_files, message_id}) do
  attrs = %{
    id: message_id,
    conversation_id: conversation_id,
    sender_id: sender_id,
    content: content,
    message_type: message_type
  }

  case @message_repo.create(attrs) do
    {:ok, message} ->
      attachment_attrs =
        Enum.map(uploaded_files, fn f ->
          %{
            message_id: message.id,
            file_url: f.url,
            original_filename: f.original_filename,
            content_type: f.content_type,
            file_size_bytes: f.file_size_bytes
          }
        end)

      case @attachment_repo.create_many(attachment_attrs) do
        {:ok, attachments} ->
          {:ok, %{message | attachments: attachments}}

        {:error, reason} ->
          cleanup_uploaded_files(uploaded_files)
          {:error, reason}
      end

    {:error, reason} ->
      cleanup_uploaded_files(uploaded_files)
      {:error, reason}
  end
end

defp persist_message_and_attachments(conversation_id, sender_id, content, message_type, []) do
  create_message(conversation_id, sender_id, content, message_type)
end

defp cleanup_uploaded_files(files) do
  Enum.each(files, fn
    %{path: path} -> Storage.delete(:public, path)
    _ -> :ok
  end)
end
```

Update `publish_event/1` to include attachments:

```elixir
defp publish_event(message) do
  event =
    MessagingEvents.message_sent(
      message.conversation_id,
      message.id,
      message.sender_id,
      message.content,
      message.message_type,
      message.inserted_at,
      message.attachments
    )

  DomainEventBus.dispatch(@context, event)
  :ok
end
```

Remove the old `create_message/4` private function (its logic is now in `persist_message_and_attachments`).

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/klass_hero/messaging/application/use_cases/send_message_test.exs`
Expected: All tests PASS (both existing and new).

Note: The S3 upload tests work because in the test environment, the Storage adapter is a stub that returns `{:ok, "https://stub-url/..."}`. Verify this with Tidewave:

```
project_eval(code: "Application.get_env(:klass_hero, :storage)")
```

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/messaging/application/use_cases/send_message.ex \
        test/klass_hero/messaging/application/use_cases/send_message_test.exs
git commit -m "feat: support attachments in SendMessage use case with S3 upload"
```

---

## Task 9: Event Handlers Update

**Files:**
- Modify: `lib/klass_hero/messaging/adapters/driving/events/event_handlers/promote_integration_events.ex`
- Modify: `lib/klass_hero/messaging/adapters/driving/events/event_handlers/notify_live_views.ex`

- [ ] **Step 1: Read current handlers with Tidewave**

```
get_source_location(reference: "KlassHero.Messaging.Adapters.Driving.Events.EventHandlers.PromoteIntegrationEvents")
```

- [ ] **Step 2: Update PromoteIntegrationEvents**

In the `:message_sent` handler, forward attachments in the integration event payload:

```elixir
defp promote(:message_sent, event) do
  payload = %{
    sender_id: event.payload.sender_id,
    content: event.payload.content,
    message_type: event.payload[:message_type],
    sent_at: event.payload[:sent_at],
    attachments: event.payload[:attachments] || []
  }

  integration_event =
    MessagingIntegrationEvents.message_sent(event.aggregate_id, payload)

  IntegrationEventPublishing.publish_critical(integration_event, event)
end
```

- [ ] **Step 3: Update NotifyLiveViews**

The `:message_sent` handler already broadcasts the full event payload. Since the domain event now includes `attachments`, LiveViews will automatically receive attachment data. No code changes needed — verify with:

```
get_source_location(reference: "KlassHero.Messaging.Adapters.Driving.Events.EventHandlers.NotifyLiveViews")
```

Read the handler and confirm it forwards `event.payload` as-is.

- [ ] **Step 4: Run messaging tests**

Run: `mix test test/klass_hero/messaging/`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/adapters/driving/events/event_handlers/promote_integration_events.ex
git commit -m "feat: forward attachment metadata in integration events"
```

---

## Task 10: ConversationSummaries Projection Update

**Files:**
- Modify: `lib/klass_hero/messaging/adapters/driven/persistence/schemas/conversation_summary_schema.ex`
- Modify: `lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex`

- [ ] **Step 1: Read current projection with Tidewave**

```
get_source_location(reference: "KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries")
```

- [ ] **Step 2: Update ConversationSummarySchema**

Add to schema fields:

```elixir
field :has_attachments, :boolean, default: false
```

- [ ] **Step 3: Update projection — message_sent handler**

In the `project_message_sent/1` function, update the SET clause to include `has_attachments`:

```elixir
has_attachments = (event.payload[:attachments] || []) != []
```

Add `has_attachments: has_attachments` to the update query's SET clause where `latest_message_content`, `latest_message_sender_id`, and `latest_message_at` are set.

- [ ] **Step 4: Update projection — bootstrap**

In the bootstrap function that fetches latest messages, derive `has_attachments` using an EXISTS subquery against `message_attachments`:

```elixir
has_attachments =
  from(a in "message_attachments",
    where: a.message_id == parent_as(:latest_msg).id,
    select: true,
    limit: 1
  )
  |> exists()
```

Include this in the row construction during bootstrap.

- [ ] **Step 5: Verify with Tidewave**

```
execute_sql_query(query: "SELECT has_attachments FROM conversation_summaries LIMIT 5")
```

- [ ] **Step 6: Run messaging tests**

Run: `mix test test/klass_hero/messaging/`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero/messaging/adapters/driven/persistence/schemas/conversation_summary_schema.ex \
        lib/klass_hero/messaging/adapters/driven/projections/conversation_summaries.ex
git commit -m "feat: project has_attachments in conversation summaries"
```

---

## Task 11: Retention Policy S3 Cleanup

**Files:**
- Modify: `lib/klass_hero/messaging/application/use_cases/enforce_retention_policy.ex`

- [ ] **Step 1: Update retention policy to clean up S3 files**

In `lib/klass_hero/messaging/application/use_cases/enforce_retention_policy.ex`:

Add:

```elixir
alias KlassHero.Shared.Storage

@attachment_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_attachments])
```

Before the transaction in `run_retention_transaction/1`, add S3 cleanup. The key insight: we must fetch URLs BEFORE the transaction deletes message records (which cascade-deletes attachment records).

```elixir
defp run_retention_transaction(now) do
  # Fetch S3 URLs before transaction (cascade will remove records)
  conversation_ids = @conversation_repo.list_expired_ids(now)
  {:ok, file_urls} = @attachment_repo.get_urls_for_conversations(conversation_ids)

  result =
    Repo.transaction(fn ->
      with {:ok, msg_count, _conv_ids} <-
             @message_repo.delete_for_expired_conversations(now),
           {:ok, conv_count} <- @conversation_repo.delete_expired(now) do
        %{messages_deleted: msg_count, conversations_deleted: conv_count}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)

  # Clean up S3 files after successful transaction
  case result do
    {:ok, _} ->
      cleanup_s3_files(file_urls)
      result

    error ->
      error
  end
end

defp cleanup_s3_files(urls) do
  Enum.each(urls, fn url ->
    case Storage.delete(:public, url) do
      :ok -> :ok
      {:error, reason} ->
        Logger.warning("Failed to delete S3 file during retention cleanup",
          file_url: url,
          reason: inspect(reason)
        )
    end
  end)
end
```

Note: Check if `list_expired_ids/1` exists on the conversation repo. If not, use `execute_sql_query` via Tidewave to query expired conversation IDs, or add this callback to the conversation port/repo. Adapt the approach based on what's available.

- [ ] **Step 2: Run tests**

Run: `mix test test/klass_hero/messaging/`
Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/klass_hero/messaging/application/use_cases/enforce_retention_policy.ex
git commit -m "feat: clean up S3 attachment files during retention enforcement"
```

---

## Task 12: LiveView Upload Handling

**Files:**
- Modify: `lib/klass_hero_web/live/messaging_live_helper.ex`

- [ ] **Step 1: Look up LiveView upload API with Tidewave**

```
search_package_docs("allow_upload" -p phoenix_live_view)
get_docs(reference: "Phoenix.LiveView.allow_upload/3")
get_docs(reference: "Phoenix.LiveView.consume_uploaded_entries/3")
```

- [ ] **Step 2: Update messaging_live_helper.ex mount**

In the `mount_conversation_show/3` function (or wherever the socket is set up in the `:show` macro), add:

```elixir
|> allow_upload(:attachments,
  accept: ~w(.jpg .jpeg .png .gif .webp),
  max_entries: 5,
  max_file_size: 10_485_760
)
```

- [ ] **Step 3: Update handle_send_message**

Update the `handle_send_message` handler to consume uploads:

```elixir
defp handle_send_message(socket, %{"content" => content}) do
  file_data =
    consume_uploaded_entries(socket, :attachments, fn %{path: path}, entry ->
      {:ok, binary} = File.read(path)

      {:ok,
       %{
         binary: binary,
         filename: entry.client_name,
         content_type: entry.client_type,
         size: entry.client_size
       }}
    end)

  content = if content == "", do: nil, else: content
  user_id = socket.assigns.current_scope.user.id
  conversation_id = socket.assigns.conversation.id

  opts =
    if file_data != [] do
      [attachments: file_data, conversation: socket.assigns.conversation]
    else
      [conversation: socket.assigns.conversation]
    end

  case Messaging.send_message(conversation_id, user_id, content, opts) do
    {:ok, _message} ->
      {:noreply, assign(socket, form: to_form(%{"content" => ""}, as: :message))}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, upload_error_message(reason))}
  end
end

defp upload_error_message(:empty_message), do: "Please enter a message or attach a photo."
defp upload_error_message(:invalid_attachments), do: "Invalid attachment. Check file type and size."
defp upload_error_message(:upload_failed), do: "Failed to upload files. Please try again."
defp upload_error_message(_), do: "Something went wrong. Please try again."
```

- [ ] **Step 4: Run the app and verify with Tidewave**

```
get_logs(tail: 20, grep: "attachment")
```

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero_web/live/messaging_live_helper.ex
git commit -m "feat: add file upload handling to messaging LiveView"
```

---

## Task 13: Component Updates — Message Bubble and Inbox Preview

**Files:**
- Modify: `lib/klass_hero_web/components/messaging_components.ex`

- [ ] **Step 1: Read current components with Tidewave**

```
get_source_location(reference: "KlassHeroWeb.MessagingComponents")
```

- [ ] **Step 2: Update message_bubble component**

Add attachment rendering to `message_bubble/1`. After the text content section, add:

```heex
<div :if={@message.attachments != []} class={[
  "grid gap-1",
  if(length(@message.attachments) == 1, do: "grid-cols-1", else: "grid-cols-2")
]}>
  <img
    :for={attachment <- @message.attachments}
    src={attachment.file_url}
    alt={attachment.original_filename}
    loading="lazy"
    class="rounded-lg w-full h-auto max-h-64 object-cover cursor-pointer"
  />
</div>
```

- [ ] **Step 3: Update conversation_card component**

Update the latest message preview to show attachment indicator. Where `latest_message_content` is displayed:

```heex
<span :if={@summary.has_attachments} class="inline-flex items-center gap-1">
  <.icon name="hero-camera" class="h-3.5 w-3.5" />
</span>
<span :if={@summary.has_attachments and is_nil(@summary.latest_message_content)}>
  Photo
</span>
<span :if={@summary.latest_message_content}>
  {String.slice(@summary.latest_message_content || "", 0..49)}
</span>
```

- [ ] **Step 4: Add upload UI to message input**

In the message input area of `conversation_show`, add the file input and preview:

```heex
<%!-- Attachment previews --%>
<div :if={@uploads.attachments.entries != []} class="flex gap-2 px-3 pt-2 overflow-x-auto">
  <div :for={entry <- @uploads.attachments.entries} class="relative flex-shrink-0">
    <.live_img_preview entry={entry} class="h-16 w-16 rounded-lg object-cover" />
    <button
      type="button"
      phx-click="cancel-upload"
      phx-value-ref={entry.ref}
      class="absolute -top-1 -right-1 bg-red-500 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs"
      aria-label="Remove attachment"
    >
      &times;
    </button>
  </div>
</div>

<%!-- File input --%>
<.live_file_input upload={@uploads.attachments} class="hidden" />
<button type="button" onclick={"document.getElementById('#{@uploads.attachments.ref}').click()"}>
  <.icon name="hero-paper-clip" class="h-5 w-5 text-zinc-400 hover:text-zinc-200" />
</button>
```

- [ ] **Step 5: Add cancel-upload event handler**

In `messaging_live_helper.ex`, add:

```elixir
def handle_event("cancel-upload", %{"ref" => ref}, socket) do
  {:noreply, cancel_upload(socket, :attachments, ref)}
end
```

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/components/messaging_components.ex \
        lib/klass_hero_web/live/messaging_live_helper.ex
git commit -m "feat: add photo rendering in message bubbles and upload UI"
```

---

## Task 14: Final Verification and Precommit

- [ ] **Step 1: Run full precommit**

Run: `mix precommit`
Expected: Compilation (zero warnings), formatting, and all tests PASS.

- [ ] **Step 2: Verify with Tidewave — end-to-end**

```
project_eval(code: """
  # Verify Attachment model is accessible
  KlassHero.Messaging.Domain.Models.Attachment.allowed_content_types()
""")

execute_sql_query(query: "SELECT count(*) as count FROM information_schema.tables WHERE table_name = 'message_attachments'")

get_logs(tail: 50, grep: "error")
```

- [ ] **Step 3: Push to remote**

```bash
git pull --rebase
git push
git status
```

Expected: "Your branch is up to date with 'origin/feat/362-photo-attachments-in-messages'."
