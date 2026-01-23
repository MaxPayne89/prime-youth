defmodule KlassHero.Messaging.Application.UseCases.SendMessageTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository
  alias KlassHero.Messaging.Application.UseCases.SendMessage
  alias KlassHero.Messaging.Domain.Models.Message

  describe "execute/4" do
    test "sends message successfully for participant" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      assert {:ok, message} =
               SendMessage.execute(conversation.id, user.id, "Hello, world!")

      assert %Message{} = message
      assert message.conversation_id == conversation.id
      assert message.sender_id == user.id
      assert message.content == "Hello, world!"
      assert message.message_type == :text
    end

    test "trims whitespace from content" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      assert {:ok, message} =
               SendMessage.execute(conversation.id, user.id, "  Hello, world!  ")

      assert message.content == "Hello, world!"
    end

    test "updates sender's last_read_at" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id,
        last_read_at: nil
      )

      # Truncate to second since utc_datetime fields don't have microsecond precision
      before = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, _message} = SendMessage.execute(conversation.id, user.id, "Hello!")

      {:ok, participant} = ParticipantRepository.get(conversation.id, user.id)
      assert participant.last_read_at != nil
      assert DateTime.compare(participant.last_read_at, before) in [:gt, :eq]
    end

    test "returns not_participant error for non-participant" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      assert {:error, :not_participant} =
               SendMessage.execute(conversation.id, user.id, "Hello!")
    end

    test "allows system message type" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      assert {:ok, message} =
               SendMessage.execute(
                 conversation.id,
                 user.id,
                 "User joined",
                 message_type: :system
               )

      assert message.message_type == :system
    end

    test "returns error for participant who has left" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id,
        left_at: DateTime.utc_now()
      )

      assert {:error, :not_participant} =
               SendMessage.execute(conversation.id, user.id, "Hello!")
    end
  end
end
