defmodule KlassHero.Messaging.Application.UseCases.GetTotalUnreadCountTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Application.UseCases.GetTotalUnreadCount

  describe "execute/1" do
    test "returns 0 for user with no conversations" do
      user = AccountsFixtures.user_fixture()

      assert GetTotalUnreadCount.execute(user.id) == 0
    end

    test "returns 0 for user with all messages read" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id,
        last_read_at: DateTime.utc_now()
      )

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: other_user.id
      )

      # Message sent before last_read_at
      insert(:message_schema,
        conversation_id: conversation.id,
        sender_id: other_user.id,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1, :hour)
      )

      assert GetTotalUnreadCount.execute(user.id) == 0
    end

    test "returns correct count of unread messages" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      last_read = DateTime.utc_now() |> DateTime.add(-1, :hour)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id,
        last_read_at: last_read
      )

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: other_user.id
      )

      # Unread messages (after last_read_at)
      for _ <- 1..3 do
        insert(:message_schema,
          conversation_id: conversation.id,
          sender_id: other_user.id,
          inserted_at: DateTime.utc_now()
        )
      end

      assert GetTotalUnreadCount.execute(user.id) == 3
    end

    test "returns correct count across multiple conversations" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()

      last_read = DateTime.utc_now() |> DateTime.add(-1, :hour)

      # First conversation with 2 unread
      conv1 = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conv1.id,
        user_id: user.id,
        last_read_at: last_read
      )

      insert(:participant_schema,
        conversation_id: conv1.id,
        user_id: other_user.id
      )

      for _ <- 1..2 do
        insert(:message_schema,
          conversation_id: conv1.id,
          sender_id: other_user.id,
          inserted_at: DateTime.utc_now()
        )
      end

      # Second conversation with 3 unread
      conv2 = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conv2.id,
        user_id: user.id,
        last_read_at: last_read
      )

      insert(:participant_schema,
        conversation_id: conv2.id,
        user_id: other_user.id
      )

      for _ <- 1..3 do
        insert(:message_schema,
          conversation_id: conv2.id,
          sender_id: other_user.id,
          inserted_at: DateTime.utc_now()
        )
      end

      assert GetTotalUnreadCount.execute(user.id) == 5
    end

    test "excludes archived conversations" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()

      archived_conversation =
        insert(:conversation_schema,
          archived_at: DateTime.utc_now()
        )

      insert(:participant_schema,
        conversation_id: archived_conversation.id,
        user_id: user.id,
        last_read_at: nil
      )

      insert(:participant_schema,
        conversation_id: archived_conversation.id,
        user_id: other_user.id
      )

      insert(:message_schema,
        conversation_id: archived_conversation.id,
        sender_id: other_user.id,
        inserted_at: DateTime.utc_now()
      )

      assert GetTotalUnreadCount.execute(user.id) == 0
    end

    test "excludes messages from conversations user has left" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id,
        last_read_at: nil,
        left_at: DateTime.utc_now() |> DateTime.add(-1, :day)
      )

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: other_user.id
      )

      insert(:message_schema,
        conversation_id: conversation.id,
        sender_id: other_user.id,
        inserted_at: DateTime.utc_now()
      )

      assert GetTotalUnreadCount.execute(user.id) == 0
    end

    test "counts all messages when last_read_at is nil" do
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

      for _ <- 1..4 do
        insert(:message_schema,
          conversation_id: conversation.id,
          sender_id: other_user.id
        )
      end

      assert GetTotalUnreadCount.execute(user.id) == 4
    end

    test "excludes deleted messages" do
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

      # Deleted message
      insert(:message_schema,
        conversation_id: conversation.id,
        sender_id: other_user.id,
        deleted_at: DateTime.utc_now()
      )

      # Active message
      insert(:message_schema,
        conversation_id: conversation.id,
        sender_id: other_user.id
      )

      assert GetTotalUnreadCount.execute(user.id) == 1
    end
  end
end
