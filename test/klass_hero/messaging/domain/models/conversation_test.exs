defmodule KlassHero.Messaging.Domain.Models.ConversationTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.Models.Conversation

  describe "new/1" do
    test "creates conversation with valid direct attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        type: :direct,
        provider_id: Ecto.UUID.generate()
      }

      assert {:ok, conversation} = Conversation.new(attrs)
      assert conversation.id == attrs.id
      assert conversation.type == :direct
      assert conversation.provider_id == attrs.provider_id
      assert conversation.lock_version == 1
      assert conversation.participants == []
      assert conversation.messages == []
    end

    test "creates conversation with valid broadcast attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        type: :program_broadcast,
        provider_id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        subject: "Important Update"
      }

      assert {:ok, conversation} = Conversation.new(attrs)
      assert conversation.type == :program_broadcast
      assert conversation.program_id == attrs.program_id
      assert conversation.subject == "Important Update"
    end

    test "returns error when id is missing" do
      attrs = %{
        type: :direct,
        provider_id: Ecto.UUID.generate()
      }

      assert {:error, ["Missing required fields"]} = Conversation.new(attrs)
    end

    test "returns error when id is empty string" do
      attrs = %{
        id: "",
        type: :direct,
        provider_id: Ecto.UUID.generate()
      }

      assert {:error, errors} = Conversation.new(attrs)
      assert "id cannot be empty" in errors
    end

    test "returns error when provider_id is missing" do
      attrs = %{
        id: Ecto.UUID.generate(),
        type: :direct
      }

      assert {:error, ["Missing required fields"]} = Conversation.new(attrs)
    end

    test "returns error when provider_id is empty string" do
      attrs = %{
        id: Ecto.UUID.generate(),
        type: :direct,
        provider_id: ""
      }

      assert {:error, errors} = Conversation.new(attrs)
      assert "provider_id cannot be empty" in errors
    end

    test "returns error when type is invalid" do
      attrs = %{
        id: Ecto.UUID.generate(),
        type: :invalid_type,
        provider_id: Ecto.UUID.generate()
      }

      assert {:error, errors} = Conversation.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "type must be one of:"))
    end

    test "returns error when program_id is missing for broadcast type" do
      attrs = %{
        id: Ecto.UUID.generate(),
        type: :program_broadcast,
        provider_id: Ecto.UUID.generate()
      }

      assert {:error, errors} = Conversation.new(attrs)
      assert "program_id is required for program_broadcast conversations" in errors
    end

    test "allows nil program_id for direct type" do
      attrs = %{
        id: Ecto.UUID.generate(),
        type: :direct,
        provider_id: Ecto.UUID.generate(),
        program_id: nil
      }

      assert {:ok, conversation} = Conversation.new(attrs)
      assert is_nil(conversation.program_id)
    end
  end

  describe "direct?/1" do
    test "returns true for direct conversation" do
      {:ok, conversation} = build_conversation(:direct)
      assert Conversation.direct?(conversation)
    end

    test "returns false for broadcast conversation" do
      {:ok, conversation} = build_conversation(:program_broadcast)
      refute Conversation.direct?(conversation)
    end
  end

  describe "broadcast?/1" do
    test "returns true for broadcast conversation" do
      {:ok, conversation} = build_conversation(:program_broadcast)
      assert Conversation.broadcast?(conversation)
    end

    test "returns false for direct conversation" do
      {:ok, conversation} = build_conversation(:direct)
      refute Conversation.broadcast?(conversation)
    end
  end

  describe "archived?/1" do
    test "returns false when archived_at is nil" do
      {:ok, conversation} = build_conversation(:direct)
      refute Conversation.archived?(conversation)
    end

    test "returns true when archived_at is set" do
      {:ok, conversation} = build_conversation(:direct)
      conversation = %{conversation | archived_at: DateTime.utc_now()}
      assert Conversation.archived?(conversation)
    end
  end

  describe "active?/1" do
    test "returns true when not archived" do
      {:ok, conversation} = build_conversation(:direct)
      assert Conversation.active?(conversation)
    end

    test "returns false when archived" do
      {:ok, conversation} = build_conversation(:direct)
      conversation = %{conversation | archived_at: DateTime.utc_now()}
      refute Conversation.active?(conversation)
    end
  end

  describe "archive/2" do
    test "sets archived_at and retention_until" do
      {:ok, conversation} = build_conversation(:direct)
      now = ~U[2025-01-15 12:00:00Z]

      assert {:ok, archived} = Conversation.archive(conversation, now)
      assert archived.archived_at == now
      assert archived.retention_until == DateTime.add(now, 30, :day)
    end

    test "increments lock_version" do
      {:ok, conversation} = build_conversation(:direct)
      initial_version = conversation.lock_version

      {:ok, archived} = Conversation.archive(conversation)
      assert archived.lock_version == initial_version + 1
    end
  end

  describe "valid_types/0" do
    test "returns all valid conversation types" do
      types = Conversation.valid_types()

      assert :direct in types
      assert :program_broadcast in types
      assert length(types) == 2
    end
  end

  defp build_conversation(type) do
    base_attrs = %{
      id: Ecto.UUID.generate(),
      type: type,
      provider_id: Ecto.UUID.generate()
    }

    attrs =
      case type do
        :program_broadcast ->
          Map.put(base_attrs, :program_id, Ecto.UUID.generate())

        _ ->
          base_attrs
      end

    Conversation.new(attrs)
  end
end
