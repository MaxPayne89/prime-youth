defmodule KlassHero.Messaging.Application.UseCases.SendMessageTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.ConversationMapper
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ProgramStaffParticipantRepository
  alias KlassHero.Messaging.Application.UseCases.SendMessage
  alias KlassHero.Messaging.Domain.Models.Conversation
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

    test "rejects message from parent in broadcast conversation" do
      # Create provider with a known user
      provider_user = AccountsFixtures.user_fixture()
      provider = insert(:provider_profile_schema, identity_id: provider_user.id)

      # Create broadcast conversation owned by provider
      program = insert(:program_schema)

      broadcast =
        insert(:conversation_schema,
          type: "program_broadcast",
          provider_id: provider.id,
          program_id: program.id,
          subject: "Announcement"
        )

      # Parent is a participant but should not be able to send
      parent_user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: broadcast.id,
        user_id: parent_user.id
      )

      assert {:error, :broadcast_reply_not_allowed} =
               SendMessage.execute(broadcast.id, parent_user.id, "My reply")
    end

    test "allows provider to send in their own broadcast conversation" do
      provider_user = AccountsFixtures.user_fixture()
      provider = insert(:provider_profile_schema, identity_id: provider_user.id)
      program = insert(:program_schema)

      broadcast =
        insert(:conversation_schema,
          type: "program_broadcast",
          provider_id: provider.id,
          program_id: program.id,
          subject: "Announcement"
        )

      insert(:participant_schema,
        conversation_id: broadcast.id,
        user_id: provider_user.id
      )

      assert {:ok, message} =
               SendMessage.execute(broadcast.id, provider_user.id, "Follow-up!")

      assert message.content == "Follow-up!"
    end

    test "allows provider to send in broadcast when pre-fetched conversation is passed" do
      provider_user = AccountsFixtures.user_fixture()
      provider = insert(:provider_profile_schema, identity_id: provider_user.id)
      program = insert(:program_schema)

      broadcast =
        insert(:conversation_schema,
          type: "program_broadcast",
          provider_id: provider.id,
          program_id: program.id,
          subject: "Announcement"
        )

      insert(:participant_schema,
        conversation_id: broadcast.id,
        user_id: provider_user.id
      )

      domain_conversation = ConversationMapper.to_domain(broadcast)
      assert %Conversation{} = domain_conversation

      assert {:ok, message} =
               SendMessage.execute(broadcast.id, provider_user.id, "Fast path!", conversation: domain_conversation)

      assert message.content == "Fast path!"
    end

    test "rejects mismatched conversation struct — falls back to DB fetch" do
      provider_user = AccountsFixtures.user_fixture()
      provider = insert(:provider_profile_schema, identity_id: provider_user.id)
      program = insert(:program_schema)

      broadcast =
        insert(:conversation_schema,
          type: "program_broadcast",
          provider_id: provider.id,
          program_id: program.id,
          subject: "Announcement"
        )

      parent_user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: broadcast.id,
        user_id: parent_user.id
      )

      # Build a direct conversation domain struct with a different ID
      direct = insert(:conversation_schema, type: "direct", provider_id: provider.id)
      mismatched_conversation = ConversationMapper.to_domain(direct)

      # Trigger: parent passes a direct conversation struct targeting a broadcast conversation_id
      # Why: the ID mismatch must cause a DB fetch, which correctly identifies the broadcast
      # Outcome: parent is still rejected from broadcast
      assert {:error, :broadcast_reply_not_allowed} =
               SendMessage.execute(broadcast.id, parent_user.id, "Sneaky reply", conversation: mismatched_conversation)
    end
  end

  describe "broadcast send permission for staff" do
    test "allows assigned staff to send in broadcast" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)
      staff_user = AccountsFixtures.user_fixture()

      broadcast =
        insert(:conversation_schema,
          type: "program_broadcast",
          provider_id: provider.id,
          program_id: program.id,
          subject: "Announcement"
        )

      insert(:participant_schema, conversation_id: broadcast.id, user_id: staff_user.id)

      ProgramStaffParticipantRepository.upsert_active(%{
        provider_id: provider.id,
        program_id: program.id,
        staff_user_id: staff_user.id
      })

      assert {:ok, message} =
               SendMessage.execute(broadcast.id, staff_user.id, "Hello from staff!")

      assert message.content == "Hello from staff!"
    end

    test "rejects user who is not owner and not assigned staff in broadcast" do
      provider_user = AccountsFixtures.user_fixture()
      provider = insert(:provider_profile_schema, identity_id: provider_user.id)
      program = insert(:program_schema, provider_id: provider.id)
      non_staff_user = AccountsFixtures.user_fixture()

      broadcast =
        insert(:conversation_schema,
          type: "program_broadcast",
          provider_id: provider.id,
          program_id: program.id,
          subject: "Announcement"
        )

      insert(:participant_schema, conversation_id: broadcast.id, user_id: non_staff_user.id)

      assert {:error, :broadcast_reply_not_allowed} =
               SendMessage.execute(broadcast.id, non_staff_user.id, "Sneaky reply")
    end
  end
end
