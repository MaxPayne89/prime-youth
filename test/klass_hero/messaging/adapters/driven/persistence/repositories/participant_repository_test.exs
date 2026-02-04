defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ParticipantRepository
  alias KlassHero.Messaging.Domain.Models.Participant

  describe "add/1" do
    test "adds participant with valid attributes" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      attrs = %{
        conversation_id: conversation.id,
        user_id: user.id
      }

      assert {:ok, participant} = ParticipantRepository.add(attrs)
      assert %Participant{} = participant
      assert participant.conversation_id == conversation.id
      assert participant.user_id == user.id
      assert participant.joined_at != nil
    end

    test "returns already_participant error for duplicate" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      attrs = %{
        conversation_id: conversation.id,
        user_id: user.id
      }

      assert {:ok, _participant} = ParticipantRepository.add(attrs)
      assert {:error, :already_participant} = ParticipantRepository.add(attrs)
    end

    test "returns error for invalid conversation_id" do
      user = AccountsFixtures.user_fixture()

      attrs = %{
        conversation_id: Ecto.UUID.generate(),
        user_id: user.id
      }

      assert {:error, changeset} = ParticipantRepository.add(attrs)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "get/2" do
    test "returns participant when found" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      assert {:ok, participant} = ParticipantRepository.get(conversation.id, user.id)
      assert %Participant{} = participant
      assert participant.conversation_id == conversation.id
      assert participant.user_id == user.id
    end

    test "returns not_found when participant does not exist" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      assert {:error, :not_found} = ParticipantRepository.get(conversation.id, user.id)
    end
  end

  describe "list_for_conversation/1" do
    test "returns active participants ordered by joined_at" do
      conversation = insert(:conversation_schema)
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user1.id,
        joined_at: ~U[2025-01-15 10:00:00Z]
      )

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user2.id,
        joined_at: ~U[2025-01-15 12:00:00Z]
      )

      participants = ParticipantRepository.list_for_conversation(conversation.id)
      assert length(participants) == 2
      assert hd(participants).user_id == user1.id
      assert List.last(participants).user_id == user2.id
    end

    test "excludes participants who have left" do
      conversation = insert(:conversation_schema)
      active_user = AccountsFixtures.user_fixture()
      left_user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: active_user.id
      )

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: left_user.id,
        left_at: DateTime.utc_now()
      )

      participants = ParticipantRepository.list_for_conversation(conversation.id)
      assert length(participants) == 1
      assert hd(participants).user_id == active_user.id
    end

    test "returns empty list when no participants" do
      conversation = insert(:conversation_schema)

      participants = ParticipantRepository.list_for_conversation(conversation.id)
      assert participants == []
    end
  end

  describe "mark_as_read/3" do
    test "updates last_read_at timestamp" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      read_at = ~U[2025-01-15 12:00:00Z]

      assert {:ok, participant} =
               ParticipantRepository.mark_as_read(conversation.id, user.id, read_at)

      assert participant.last_read_at == read_at
    end

    test "returns not_found when participant does not exist" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      assert {:error, :not_found} =
               ParticipantRepository.mark_as_read(
                 conversation.id,
                 user.id,
                 DateTime.utc_now()
               )
    end
  end

  describe "leave/2" do
    test "sets left_at timestamp" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      assert {:ok, participant} = ParticipantRepository.leave(conversation.id, user.id)
      assert participant.left_at != nil
    end

    test "returns not_found when participant does not exist" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      assert {:error, :not_found} = ParticipantRepository.leave(conversation.id, user.id)
    end
  end

  describe "is_participant?/2" do
    test "returns true when user is active participant" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      assert ParticipantRepository.is_participant?(conversation.id, user.id)
    end

    test "returns false when user is not a participant" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      refute ParticipantRepository.is_participant?(conversation.id, user.id)
    end

    test "returns false when user has left the conversation" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id,
        left_at: DateTime.utc_now()
      )

      refute ParticipantRepository.is_participant?(conversation.id, user.id)
    end
  end

  describe "mark_all_as_left/1" do
    test "marks all active participations as left and returns count" do
      user = AccountsFixtures.user_fixture()
      conversation1 = insert(:conversation_schema)
      conversation2 = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation1.id,
        user_id: user.id,
        left_at: nil
      )

      insert(:participant_schema,
        conversation_id: conversation2.id,
        user_id: user.id,
        left_at: nil
      )

      assert {:ok, 2} = ParticipantRepository.mark_all_as_left(user.id)

      # Verify all now have left_at set
      participants =
        Repo.all(
          from(p in KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ParticipantSchema,
            where: p.user_id == ^user.id
          )
        )

      assert Enum.all?(participants, &(not is_nil(&1.left_at)))
    end

    test "does not re-update already-left participations" do
      user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id,
        left_at: ~U[2025-01-01 00:00:00Z]
      )

      assert {:ok, 0} = ParticipantRepository.mark_all_as_left(user.id)
    end

    test "returns zero count when user has no participations" do
      user = AccountsFixtures.user_fixture()

      assert {:ok, 0} = ParticipantRepository.mark_all_as_left(user.id)
    end
  end

  describe "add_batch/2" do
    test "adds multiple participants at once" do
      conversation = insert(:conversation_schema)
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()
      user3 = AccountsFixtures.user_fixture()

      user_ids = [user1.id, user2.id, user3.id]

      assert {:ok, participants} = ParticipantRepository.add_batch(conversation.id, user_ids)
      assert length(participants) == 3

      participant_user_ids = Enum.map(participants, & &1.user_id)
      assert user1.id in participant_user_ids
      assert user2.id in participant_user_ids
      assert user3.id in participant_user_ids
    end

    test "handles duplicates gracefully with on_conflict: :nothing" do
      conversation = insert(:conversation_schema)
      user1 = AccountsFixtures.user_fixture()
      user2 = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user1.id
      )

      user_ids = [user1.id, user2.id]

      assert {:ok, participants} = ParticipantRepository.add_batch(conversation.id, user_ids)
      assert length(participants) == 1
      assert hd(participants).user_id == user2.id
    end

    test "returns empty list when all users are already participants" do
      conversation = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      assert {:ok, participants} = ParticipantRepository.add_batch(conversation.id, [user.id])
      assert participants == []
    end
  end
end
