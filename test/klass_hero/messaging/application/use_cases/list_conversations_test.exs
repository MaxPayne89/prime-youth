defmodule KlassHero.Messaging.Application.UseCases.ListConversationsTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.MessageRepository
  alias KlassHero.Messaging.Application.UseCases.ListConversations
  alias KlassHero.Messaging.Domain.Models.Conversation

  describe "execute/2" do
    test "returns enriched conversations for user" do
      user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, _msg} =
        MessageRepository.create(%{
          conversation_id: conversation.id,
          sender_id: user.id,
          content: "Hello!"
        })

      assert {:ok, conversations, has_more} = ListConversations.execute(user.id)

      assert length(conversations) == 1
      refute has_more

      enriched = hd(conversations)
      assert %Conversation{} = enriched.conversation
      assert enriched.conversation.id == conversation.id
      assert is_integer(enriched.unread_count)
      assert enriched.latest_message != nil
      assert enriched.latest_message.content == "Hello!"
    end

    test "returns unread_count correctly" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id,
        last_read_at: nil
      )

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: other_user.id
      )

      for _i <- 1..3 do
        MessageRepository.create(%{
          conversation_id: conversation.id,
          sender_id: other_user.id,
          content: "Message"
        })
      end

      {:ok, conversations, _has_more} = ListConversations.execute(user.id)

      enriched = hd(conversations)
      assert enriched.unread_count == 3
    end

    test "returns nil latest_message when no messages" do
      user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, conversations, _has_more} = ListConversations.execute(user.id)

      enriched = hd(conversations)
      assert is_nil(enriched.latest_message)
    end

    test "includes other_participant_name for direct conversations" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: other_user.id
      )

      {:ok, conversations, _has_more} = ListConversations.execute(user.id)

      enriched = hd(conversations)
      assert enriched.other_participant_name != nil
    end

    test "respects pagination limit" do
      user = AccountsFixtures.user_fixture()

      for _i <- 1..5 do
        conversation = insert(:conversation_schema)

        insert(:participant_schema,
          conversation_id: conversation.id,
          user_id: user.id
        )
      end

      {:ok, conversations, has_more} = ListConversations.execute(user.id, limit: 3)

      assert length(conversations) == 3
      assert has_more
    end

    test "returns empty list when user has no conversations" do
      user = AccountsFixtures.user_fixture()

      {:ok, conversations, has_more} = ListConversations.execute(user.id)

      assert conversations == []
      refute has_more
    end

    test "excludes archived conversations" do
      user = AccountsFixtures.user_fixture()

      archived = insert(:conversation_schema, archived_at: DateTime.utc_now())

      insert(:participant_schema,
        conversation_id: archived.id,
        user_id: user.id
      )

      active = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: active.id,
        user_id: user.id
      )

      {:ok, conversations, _has_more} = ListConversations.execute(user.id)

      assert length(conversations) == 1
      assert hd(conversations).conversation.id == active.id
    end
  end
end
