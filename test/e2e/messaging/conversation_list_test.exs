defmodule KlassHeroWeb.E2E.Messaging.ConversationListTest do
  @moduledoc """
  E2E tests for conversation list flows.

  Scenario 5: Conversation list updates with new message preview.
  Scenario 6: Unread count updates when a new message arrives.
  """

  use KlassHeroWeb.E2ECase

  describe "conversation list" do
    setup %{sandbox_metadata: metadata} do
      %{conversation: conversation} =
        data = setup_dm_conversation("Welcome to our program!")

      provider_session = new_session(metadata) |> log_in(data.provider_user)
      parent_session = new_session(metadata) |> log_in(data.parent_user)

      %{
        provider_session: provider_session,
        parent_session: parent_session,
        conversation: conversation
      }
    end

    test "conversation list shows new message preview", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      parent_session
      |> visit_conversations(:parent)
      |> assert_has(Query.css("[data-role=conversation-card]", text: "Welcome to our program!"))

      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> send_message("Class is moved to Room 204 tomorrow")

      wait_and_rebuild_summaries()

      parent_session
      |> visit_conversations(:parent)
      |> assert_has(
        Query.css("[data-role=conversation-card]", text: "Class is moved to Room 204 tomorrow")
      )
    end

    test "unread count updates when new message arrives", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      # Open conversation to mark existing messages as read
      parent_session
      |> visit("/messages/#{conversation.id}")
      |> assert_message_visible("Welcome to our program!")

      # mark_as_read fires on connected mount — wait for it to complete
      wait_and_rebuild_summaries()

      parent_session
      |> visit_conversations(:parent)
      |> refute_unread_count()

      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> send_message("New homework assignment posted")

      wait_and_rebuild_summaries()

      parent_session
      |> visit_conversations(:parent)
      |> assert_unread_count(1)
    end
  end
end
