defmodule KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummariesTest do
  use KlassHero.DataCase, async: false

  import Ecto.Query
  import KlassHero.Factory

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.MessageSchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ParticipantSchema
  alias KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries
  alias KlassHero.Repo
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  # Use a unique name to avoid conflicts with the supervision tree
  @test_server_name :conversation_summaries_projection_test

  setup do
    pid = start_supervised!({ConversationSummaries, name: @test_server_name})
    {:ok, pid: pid}
  end

  describe "bootstrap" do
    test "projects existing conversations into conversation_summaries on startup" do
      # Create two users for a direct conversation
      user_1 = user_fixture(name: "Alice Smith")
      user_2 = user_fixture(name: "Bob Jones")

      # Trigger: conversations table has FK to provider_profiles
      # Why: must create a real provider to satisfy referential integrity
      # Outcome: provider_id is valid for conversation inserts
      provider = insert(:provider_profile_schema)

      # Create a conversation in the write table
      conversation_id = Ecto.UUID.generate()

      Repo.insert!(%ConversationSchema{
        id: conversation_id,
        type: "direct",
        provider_id: provider.id
      })

      # Create participants
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      five_min_ago = DateTime.add(now, -300, :second)

      Repo.insert!(%ParticipantSchema{
        id: Ecto.UUID.generate(),
        conversation_id: conversation_id,
        user_id: user_1.id,
        joined_at: now,
        last_read_at: five_min_ago
      })

      Repo.insert!(%ParticipantSchema{
        id: Ecto.UUID.generate(),
        conversation_id: conversation_id,
        user_id: user_2.id,
        joined_at: now,
        last_read_at: nil
      })

      # Create messages — one before and one after user_1's last_read_at
      Repo.insert!(%MessageSchema{
        id: Ecto.UUID.generate(),
        conversation_id: conversation_id,
        sender_id: user_2.id,
        content: "Old message",
        message_type: "text",
        inserted_at: DateTime.add(five_min_ago, -60, :second),
        updated_at: DateTime.add(five_min_ago, -60, :second)
      })

      Repo.insert!(%MessageSchema{
        id: Ecto.UUID.generate(),
        conversation_id: conversation_id,
        sender_id: user_2.id,
        content: "Latest message",
        message_type: "text",
        inserted_at: now,
        updated_at: now
      })

      # Stop the default test server and start a fresh one so it bootstraps
      stop_supervised!(ConversationSummaries)

      bootstrap_name = :"bootstrap_test_#{System.unique_integer([:positive])}"

      bootstrap_pid =
        start_supervised!({ConversationSummaries, name: bootstrap_name}, id: :bootstrap)

      # Synchronize: ensure bootstrap has completed
      _ = :sys.get_state(bootstrap_pid)

      # Verify user_1's summary row
      summary_1 =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_1.id
          )
        )

      assert summary_1 != nil
      assert summary_1.conversation_type == "direct"
      assert summary_1.provider_id == provider.id
      assert summary_1.other_participant_name == "Bob Jones"
      assert summary_1.participant_count == 2
      assert summary_1.latest_message_content == "Latest message"
      assert summary_1.latest_message_sender_id == user_2.id
      # user_1 has last_read_at = five_min_ago, and there's 1 message after that
      assert summary_1.unread_count == 1

      # Verify user_2's summary row
      summary_2 =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_2.id
          )
        )

      assert summary_2 != nil
      assert summary_2.other_participant_name == "Alice Smith"
      # user_2 has last_read_at = nil, but both messages were sent by user_2
      # themselves — own messages never count as unread
      assert summary_2.unread_count == 0
    end
  end

  describe "handle conversation_created event" do
    test "inserts one summary row per participant for a direct conversation" do
      user_1 = user_fixture(name: "Alice Smith")
      user_2 = user_fixture(name: "Bob Jones")

      conversation_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()

      event =
        IntegrationEvent.new(
          :conversation_created,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            type: "direct",
            provider_id: provider_id,
            program_id: nil,
            subject: nil,
            participant_ids: [user_1.id, user_2.id]
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:conversation_created",
        {:integration_event, event}
      )

      # Synchronize: ensure GenServer has processed the broadcast
      _ = :sys.get_state(@test_server_name)

      # Verify user_1's summary row
      summary_1 =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_1.id
          )
        )

      assert summary_1 != nil
      assert summary_1.conversation_type == "direct"
      assert summary_1.provider_id == provider_id
      assert summary_1.other_participant_name == "Bob Jones"
      assert summary_1.participant_count == 2
      assert summary_1.unread_count == 0

      # Verify user_2's summary row
      summary_2 =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_2.id
          )
        )

      assert summary_2 != nil
      assert summary_2.other_participant_name == "Alice Smith"
      assert summary_2.participant_count == 2
    end
  end

  describe "handle message_sent event" do
    test "updates latest_message fields and increments unread_count for non-sender" do
      user_1 = user_fixture(name: "Alice Smith")
      user_2 = user_fixture(name: "Bob Jones")

      conversation_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Seed the summary rows first via conversation_created event
      created_event =
        IntegrationEvent.new(
          :conversation_created,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            type: "direct",
            provider_id: provider_id,
            participant_ids: [user_1.id, user_2.id]
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:conversation_created",
        {:integration_event, created_event}
      )

      _ = :sys.get_state(@test_server_name)

      # Now send a message_sent event from user_1
      message_id = Ecto.UUID.generate()

      sent_event =
        IntegrationEvent.new(
          :message_sent,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            message_id: message_id,
            sender_id: user_1.id,
            content: "Hello Bob!",
            message_type: "text",
            sent_at: now
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:message_sent",
        {:integration_event, sent_event}
      )

      _ = :sys.get_state(@test_server_name)

      # user_2 should have unread_count incremented and latest message updated
      summary_2 =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_2.id
          )
        )

      assert summary_2.latest_message_content == "Hello Bob!"
      assert summary_2.latest_message_sender_id == user_1.id
      assert summary_2.latest_message_at == now
      assert summary_2.unread_count == 1

      # user_1 (sender) should have latest message updated but unread_count still 0
      summary_1 =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_1.id
          )
        )

      assert summary_1.latest_message_content == "Hello Bob!"
      assert summary_1.latest_message_sender_id == user_1.id
      assert summary_1.unread_count == 0
    end
  end

  describe "handle messages_read event" do
    test "sets unread_count to 0 and updates last_read_at for the user" do
      user_1 = user_fixture(name: "Alice Smith")
      user_2 = user_fixture(name: "Bob Jones")

      conversation_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Create conversation + send a message so user_2 has unread
      created_event =
        IntegrationEvent.new(
          :conversation_created,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            type: "direct",
            provider_id: provider_id,
            participant_ids: [user_1.id, user_2.id]
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:conversation_created",
        {:integration_event, created_event}
      )

      _ = :sys.get_state(@test_server_name)

      sent_event =
        IntegrationEvent.new(
          :message_sent,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            message_id: Ecto.UUID.generate(),
            sender_id: user_1.id,
            content: "Unread message",
            sent_at: now
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:message_sent",
        {:integration_event, sent_event}
      )

      _ = :sys.get_state(@test_server_name)

      # Verify user_2 has unread_count = 1
      summary =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_2.id
          )
        )

      assert summary.unread_count == 1

      # Now user_2 reads messages
      read_at = DateTime.add(now, 10, :second)

      read_event =
        IntegrationEvent.new(
          :messages_read,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            user_id: user_2.id,
            read_at: read_at
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:messages_read",
        {:integration_event, read_event}
      )

      _ = :sys.get_state(@test_server_name)

      # Verify unread_count is now 0
      summary =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_2.id
          )
        )

      assert summary.unread_count == 0
      assert summary.last_read_at == read_at
    end
  end

  describe "handle conversation_archived event" do
    test "sets archived_at for all participants of the conversation" do
      user_1 = user_fixture(name: "Alice Smith")
      user_2 = user_fixture(name: "Bob Jones")

      conversation_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Create conversation first
      created_event =
        IntegrationEvent.new(
          :conversation_created,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            type: "direct",
            provider_id: provider_id,
            participant_ids: [user_1.id, user_2.id]
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:conversation_created",
        {:integration_event, created_event}
      )

      _ = :sys.get_state(@test_server_name)

      # Now archive it
      archived_event =
        IntegrationEvent.new(
          :conversation_archived,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            archived_at: now
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:conversation_archived",
        {:integration_event, archived_event}
      )

      _ = :sys.get_state(@test_server_name)

      # Both participants' summary rows should have archived_at set
      summaries =
        Repo.all(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id
          )
        )

      assert length(summaries) == 2
      assert Enum.all?(summaries, fn s -> s.archived_at == now end)
    end
  end

  describe "handle conversations_archived event" do
    test "sets archived_at for all participants across multiple conversations" do
      user_1 = user_fixture(name: "Alice Smith")
      user_2 = user_fixture(name: "Bob Jones")
      provider_id = Ecto.UUID.generate()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      conv_1_id = Ecto.UUID.generate()
      conv_2_id = Ecto.UUID.generate()

      # Create two conversations
      for conv_id <- [conv_1_id, conv_2_id] do
        event =
          IntegrationEvent.new(
            :conversation_created,
            :messaging,
            :conversation,
            conv_id,
            %{
              conversation_id: conv_id,
              type: "direct",
              provider_id: provider_id,
              participant_ids: [user_1.id, user_2.id]
            }
          )

        Phoenix.PubSub.broadcast(
          KlassHero.PubSub,
          "integration:messaging:conversation_created",
          {:integration_event, event}
        )

        _ = :sys.get_state(@test_server_name)
      end

      # Bulk archive both conversations
      bulk_event =
        IntegrationEvent.new(
          :conversations_archived,
          :messaging,
          :conversation,
          "bulk_archive_#{System.unique_integer([:positive])}",
          %{
            conversation_ids: [conv_1_id, conv_2_id],
            archived_at: now
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:conversations_archived",
        {:integration_event, bulk_event}
      )

      _ = :sys.get_state(@test_server_name)

      # All 4 summary rows (2 per conversation) should have archived_at set
      summaries =
        Repo.all(
          from(s in ConversationSummarySchema,
            where: s.conversation_id in ^[conv_1_id, conv_2_id]
          )
        )

      assert length(summaries) == 4
      assert Enum.all?(summaries, fn s -> s.archived_at == now end)
    end
  end

  describe "handle message_data_anonymized event" do
    test "updates other_participant_name to 'Deleted User' for the anonymized user" do
      user_1 = user_fixture(name: "Alice Smith")
      user_2 = user_fixture(name: "Bob Jones")

      conversation_id = Ecto.UUID.generate()
      provider_id = Ecto.UUID.generate()

      # Create conversation
      created_event =
        IntegrationEvent.new(
          :conversation_created,
          :messaging,
          :conversation,
          conversation_id,
          %{
            conversation_id: conversation_id,
            type: "direct",
            provider_id: provider_id,
            participant_ids: [user_1.id, user_2.id]
          }
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:conversation_created",
        {:integration_event, created_event}
      )

      _ = :sys.get_state(@test_server_name)

      # Verify initial names are correct
      summary_1 =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_1.id
          )
        )

      assert summary_1.other_participant_name == "Bob Jones"

      # Anonymize user_2
      anonymize_event =
        IntegrationEvent.new(
          :message_data_anonymized,
          :messaging,
          :user,
          user_2.id,
          %{user_id: user_2.id}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:messaging:message_data_anonymized",
        {:integration_event, anonymize_event}
      )

      _ = :sys.get_state(@test_server_name)

      # user_1's summary should now show "Deleted User" as the other participant
      summary_1 =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_1.id
          )
        )

      assert summary_1.other_participant_name == "Deleted User"

      # user_2's summary should remain unchanged (their own name display is not affected)
      summary_2 =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id and s.user_id == ^user_2.id
          )
        )

      assert summary_2.other_participant_name == "Alice Smith"
    end
  end

  # Helper to create users with specific names
  defp user_fixture(attrs) do
    KlassHero.AccountsFixtures.user_fixture(attrs)
  end
end
