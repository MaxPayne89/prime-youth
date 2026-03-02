defmodule KlassHeroWeb.MessagingLiveHelperTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.Models.Message
  alias KlassHeroWeb.MessagingLiveHelper

  describe "get_conversation_title/1" do
    test "returns subject for a program_broadcast conversation with a subject" do
      conversation = %{type: :program_broadcast, subject: "Summer Camp Update"}

      assert MessagingLiveHelper.get_conversation_title(conversation) == "Summer Camp Update"
    end

    test "returns 'Program Broadcast' for a program_broadcast conversation without a subject" do
      conversation = %{type: :program_broadcast, subject: nil}

      assert MessagingLiveHelper.get_conversation_title(conversation) == "Program Broadcast"
    end

    test "returns 'Conversation' for any other conversation type" do
      assert MessagingLiveHelper.get_conversation_title(%{type: :direct}) == "Conversation"
      assert MessagingLiveHelper.get_conversation_title(%{type: :group}) == "Conversation"
    end
  end

  describe "own_message?/2" do
    test "returns true when the message sender is the given user" do
      user_id = "user-uuid-123"
      message = %Message{
        id: "msg-1",
        conversation_id: "conv-1",
        sender_id: user_id,
        content: "hello"
      }

      assert MessagingLiveHelper.own_message?(message, user_id) == true
    end

    test "returns false when the message sender is a different user" do
      message = %Message{
        id: "msg-1",
        conversation_id: "conv-1",
        sender_id: "sender-uuid",
        content: "hello"
      }

      assert MessagingLiveHelper.own_message?(message, "other-uuid") == false
    end
  end

  describe "get_sender_name/2" do
    test "returns the name when sender_id is present in the map" do
      sender_names = %{"user-1" => "Alice", "user-2" => "Bob"}

      assert MessagingLiveHelper.get_sender_name(sender_names, "user-1") == "Alice"
      assert MessagingLiveHelper.get_sender_name(sender_names, "user-2") == "Bob"
    end

    test "returns 'Unknown' as fallback when sender_id is not in the map" do
      assert MessagingLiveHelper.get_sender_name(%{}, "missing-id") == "Unknown"
      assert MessagingLiveHelper.get_sender_name(%{"other" => "Name"}, "missing-id") == "Unknown"
    end
  end
end
