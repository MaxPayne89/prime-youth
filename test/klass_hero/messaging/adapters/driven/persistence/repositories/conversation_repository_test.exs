defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationRepository
  alias KlassHero.Messaging.Domain.Models.Conversation

  describe "create/1" do
    test "creates direct conversation with valid attributes" do
      provider = insert(:provider_profile_schema)

      attrs = %{
        type: :direct,
        provider_id: provider.id
      }

      assert {:ok, conversation} = ConversationRepository.create(attrs)
      assert %Conversation{} = conversation
      assert conversation.type == :direct
      assert conversation.provider_id == provider.id
      assert is_nil(conversation.program_id)
    end

    test "creates broadcast conversation with valid attributes" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema)

      attrs = %{
        type: :program_broadcast,
        provider_id: provider.id,
        program_id: program.id,
        subject: "Important Update"
      }

      assert {:ok, conversation} = ConversationRepository.create(attrs)
      assert conversation.type == :program_broadcast
      assert conversation.program_id == program.id
      assert conversation.subject == "Important Update"
    end

    test "returns duplicate_broadcast error for existing active broadcast" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema)

      attrs = %{
        type: :program_broadcast,
        provider_id: provider.id,
        program_id: program.id
      }

      assert {:ok, _first} = ConversationRepository.create(attrs)
      assert {:error, :duplicate_broadcast} = ConversationRepository.create(attrs)
    end

    test "returns error when required fields are missing" do
      attrs = %{type: :direct}

      assert {:error, changeset} = ConversationRepository.create(attrs)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "get_by_id/2" do
    test "returns conversation when found" do
      conversation_schema = insert(:conversation_schema)

      assert {:ok, conversation} = ConversationRepository.get_by_id(conversation_schema.id)
      assert %Conversation{} = conversation
      assert conversation.id == conversation_schema.id
    end

    test "returns not_found when conversation does not exist" do
      assert {:error, :not_found} = ConversationRepository.get_by_id(Ecto.UUID.generate())
    end

    test "preloads participants when requested" do
      conversation_schema = insert(:conversation_schema)
      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation_schema.id,
        user_id: user.id
      )

      assert {:ok, conversation} =
               ConversationRepository.get_by_id(conversation_schema.id, preload: [:participants])

      assert length(conversation.participants) == 1
      assert hd(conversation.participants).user_id == user.id
    end
  end

  describe "find_direct_conversation/2" do
    test "returns existing direct conversation between provider and user" do
      provider = insert(:provider_profile_schema)
      user = AccountsFixtures.user_fixture()

      conversation_schema = insert(:conversation_schema, provider_id: provider.id)

      insert(:participant_schema,
        conversation_id: conversation_schema.id,
        user_id: user.id
      )

      assert {:ok, conversation} =
               ConversationRepository.find_direct_conversation(provider.id, user.id)

      assert conversation.id == conversation_schema.id
    end

    test "returns not_found when no direct conversation exists" do
      provider = insert(:provider_profile_schema)
      user = AccountsFixtures.user_fixture()

      assert {:error, :not_found} =
               ConversationRepository.find_direct_conversation(provider.id, user.id)
    end

    test "ignores archived conversations" do
      provider = insert(:provider_profile_schema)
      user = AccountsFixtures.user_fixture()

      conversation_schema =
        insert(:conversation_schema,
          provider_id: provider.id,
          archived_at: DateTime.utc_now()
        )

      insert(:participant_schema,
        conversation_id: conversation_schema.id,
        user_id: user.id
      )

      assert {:error, :not_found} =
               ConversationRepository.find_direct_conversation(provider.id, user.id)
    end
  end

  describe "list_for_user/2" do
    test "returns conversations for user" do
      user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      assert {:ok, conversations, has_more} = ConversationRepository.list_for_user(user.id)
      assert length(conversations) == 1
      assert hd(conversations).id == conversation.id
      refute has_more
    end

    test "excludes archived conversations" do
      user = AccountsFixtures.user_fixture()

      archived_conversation =
        insert(:conversation_schema,
          archived_at: DateTime.utc_now()
        )

      insert(:participant_schema,
        conversation_id: archived_conversation.id,
        user_id: user.id
      )

      assert {:ok, conversations, _has_more} = ConversationRepository.list_for_user(user.id)
      assert conversations == []
    end

    test "returns has_more when more conversations exist" do
      user = AccountsFixtures.user_fixture()

      for _i <- 1..3 do
        conversation = insert(:conversation_schema)

        insert(:participant_schema,
          conversation_id: conversation.id,
          user_id: user.id
        )
      end

      assert {:ok, conversations, has_more} =
               ConversationRepository.list_for_user(user.id, limit: 2)

      assert length(conversations) == 2
      assert has_more
    end

    test "returns empty list when user has no conversations" do
      user = AccountsFixtures.user_fixture()

      assert {:ok, [], false} = ConversationRepository.list_for_user(user.id)
    end
  end

  describe "archive/1" do
    test "sets archived_at and retention_until timestamps" do
      conversation_schema = insert(:conversation_schema)
      {:ok, conversation} = ConversationRepository.get_by_id(conversation_schema.id)

      assert {:ok, archived} = ConversationRepository.archive(conversation)
      assert archived.archived_at != nil
      assert archived.retention_until != nil
    end

    test "increments lock_version" do
      conversation_schema = insert(:conversation_schema)
      {:ok, conversation} = ConversationRepository.get_by_id(conversation_schema.id)
      initial_version = conversation.lock_version

      {:ok, archived} = ConversationRepository.archive(conversation)
      assert archived.lock_version == initial_version + 1
    end

    test "returns not_found for non-existent conversation" do
      fake_conversation = %Conversation{
        id: Ecto.UUID.generate(),
        type: :direct,
        provider_id: Ecto.UUID.generate(),
        lock_version: 1
      }

      assert {:error, :not_found} = ConversationRepository.archive(fake_conversation)
    end
  end
end
