defmodule KlassHero.Messaging.Domain.ReadModels.ConversationSummaryTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.ReadModels.ConversationSummary

  describe "new/1" do
    test "creates a ConversationSummary from a map of attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        conversation_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        conversation_type: "direct",
        provider_id: Ecto.UUID.generate(),
        other_participant_name: "Jane Smith",
        unread_count: 3,
        latest_message_content: "Hello!",
        latest_message_at: ~U[2026-02-26 10:00:00Z]
      }

      summary = ConversationSummary.new(attrs)

      assert summary.id == attrs.id
      assert summary.conversation_id == attrs.conversation_id
      assert summary.user_id == attrs.user_id
      assert summary.conversation_type == "direct"
      assert summary.provider_id == attrs.provider_id
      assert summary.other_participant_name == "Jane Smith"
      assert summary.unread_count == 3
      assert summary.latest_message_content == "Hello!"
      assert summary.latest_message_at == ~U[2026-02-26 10:00:00Z]
    end

    test "applies defaults for participant_count and unread_count" do
      attrs = %{
        id: Ecto.UUID.generate(),
        conversation_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        conversation_type: "group",
        provider_id: Ecto.UUID.generate()
      }

      summary = ConversationSummary.new(attrs)

      assert summary.participant_count == 0
      assert summary.unread_count == 0
    end

    test "raises on unknown keys (strict construction via struct!)" do
      assert_raise KeyError, fn ->
        ConversationSummary.new(%{bogus_field: "nope"})
      end
    end
  end
end
