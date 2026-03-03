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
      user_id = Ecto.UUID.generate()

      message = %Message{
        id: Ecto.UUID.generate(),
        conversation_id: Ecto.UUID.generate(),
        sender_id: user_id,
        content: "hello"
      }

      assert MessagingLiveHelper.own_message?(message, user_id) == true
    end

    test "returns false when the message sender is a different user" do
      message = %Message{
        id: Ecto.UUID.generate(),
        conversation_id: Ecto.UUID.generate(),
        sender_id: Ecto.UUID.generate(),
        content: "hello"
      }

      assert MessagingLiveHelper.own_message?(message, Ecto.UUID.generate()) == false
    end
  end

  describe "get_sender_name/2" do
    test "returns the name when sender_id is present in the map" do
      id_1 = Ecto.UUID.generate()
      id_2 = Ecto.UUID.generate()
      sender_names = %{id_1 => "Alice", id_2 => "Bob"}

      assert MessagingLiveHelper.get_sender_name(sender_names, id_1) == "Alice"
      assert MessagingLiveHelper.get_sender_name(sender_names, id_2) == "Bob"
    end

    test "returns 'Unknown' as fallback when sender_id is not in the map" do
      missing_id = Ecto.UUID.generate()

      assert MessagingLiveHelper.get_sender_name(%{}, missing_id) == "Unknown"

      assert MessagingLiveHelper.get_sender_name(%{Ecto.UUID.generate() => "Name"}, missing_id) ==
               "Unknown"
    end
  end
end
