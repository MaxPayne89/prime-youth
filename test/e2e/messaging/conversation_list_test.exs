defmodule KlassHeroWeb.E2E.Messaging.ConversationListTest do
  @moduledoc """
  E2E tests for conversation list flows.

  Scenario 5: Conversation list updates with new message preview.
  Scenario 6: Unread count updates when a new message arrives.
  """

  use KlassHeroWeb.E2ECase

  alias KlassHero.Accounts.Scope
  alias KlassHero.Messaging
  alias KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries

  describe "conversation list" do
    setup %{sandbox_metadata: metadata} do
      start_supervised!(ConversationSummaries)

      # Create provider with password
      provider_user = user_fixture(%{intended_roles: [:provider]})
      provider_user = set_password(provider_user)

      provider =
        insert(:provider_profile_schema,
          identity_id: provider_user.id,
          subscription_tier: "professional"
        )

      # Create parent with password and active tier for messaging
      parent_user = user_fixture(%{intended_roles: [:parent]})
      parent_user = set_password(parent_user)

      _parent =
        insert(:parent_profile_schema,
          identity_id: parent_user.id,
          subscription_tier: "active"
        )

      # Create direct conversation programmatically
      provider_scope = Scope.for_user(provider_user) |> Scope.resolve_roles()

      {:ok, conversation} =
        Messaging.create_direct_conversation(provider_scope, provider.id, parent_user.id)

      {:ok, _message} =
        Messaging.send_message(
          conversation.id,
          provider_user.id,
          "Welcome to our program!"
        )

      ConversationSummaries.rebuild()

      # Start browser sessions
      provider_session = new_session(metadata)
      parent_session = new_session(metadata)

      # Log in both users
      provider_session = log_in(provider_session, provider_user)
      parent_session = log_in(parent_session, parent_user)

      %{
        provider_session: provider_session,
        parent_session: parent_session,
        provider_user: provider_user,
        conversation: conversation
      }
    end

    test "conversation list shows new message preview", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      # Parent views conversation list and sees the initial message
      parent_session
      |> visit_conversations(:parent)
      |> assert_has(Query.css("[data-role=conversation-card]", text: "Welcome to our program!"))

      # Provider opens conversation and sends a new message
      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> send_message("Class is moved to Room 204 tomorrow")

      # Wait for DB commit and rebuild summaries
      Process.sleep(500)
      ConversationSummaries.rebuild()

      # Parent navigates to conversation list and sees the updated preview
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
      # Parent opens conversation to mark existing messages as read
      parent_session
      |> visit("/messages/#{conversation.id}")
      |> assert_message_visible("Welcome to our program!")

      # Wait for mark_as_read to complete (fires on connected mount)
      Process.sleep(500)
      ConversationSummaries.rebuild()

      # Parent goes back to conversation list — no unread badge expected
      parent_session
      |> visit_conversations(:parent)
      |> refute_unread_count()

      # Provider sends a new message
      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> send_message("New homework assignment posted")

      # Wait for DB commit and rebuild summaries
      Process.sleep(500)
      ConversationSummaries.rebuild()

      # Parent navigates to conversation list and sees unread count badge
      parent_session
      |> visit_conversations(:parent)
      |> assert_unread_count(1)
    end
  end
end
