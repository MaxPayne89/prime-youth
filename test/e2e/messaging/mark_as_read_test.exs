defmodule KlassHeroWeb.E2E.Messaging.MarkAsReadTest do
  @moduledoc """
  E2E test for mark-as-read flow.

  Scenario 7: Opening a conversation marks messages as read and clears the unread badge.
  """

  use KlassHeroWeb.E2ECase

  alias KlassHero.Accounts.Scope
  alias KlassHero.Messaging
  alias KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries

  describe "mark as read" do
    setup %{sandbox_metadata: metadata} do
      start_supervised!(ConversationSummaries)

      # Create provider (no browser session needed, just sends a message)
      provider_user = user_fixture(%{intended_roles: [:provider]})

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

      # Create direct conversation with an unread message for parent
      provider_scope = Scope.for_user(provider_user) |> Scope.resolve_roles()

      {:ok, conversation} =
        Messaging.create_direct_conversation(provider_scope, provider.id, parent_user.id)

      {:ok, _message} =
        Messaging.send_message(
          conversation.id,
          provider_user.id,
          "Please confirm your child's attendance."
        )

      ConversationSummaries.rebuild()

      # Start parent browser session only
      parent_session = new_session(metadata)
      parent_session = log_in(parent_session, parent_user)

      %{
        parent_session: parent_session,
        conversation: conversation
      }
    end

    test "opening conversation marks messages as read", %{
      parent_session: parent_session,
      conversation: conversation
    } do
      # Parent navigates to conversation list and sees unread badge
      parent_session
      |> visit_conversations(:parent)
      |> assert_unread_count(1)

      # Parent opens the conversation (triggers mark_as_read)
      parent_session
      |> open_conversation("Please confirm your child's attendance.")

      # Parent sees the message in the conversation
      assert_message_visible(parent_session, "Please confirm your child's attendance.")

      # Wait briefly for mark_as_read to complete
      Process.sleep(500)
      ConversationSummaries.rebuild()

      # Parent navigates back to conversation list
      parent_session
      |> visit_conversations(:parent)

      # Unread badge should be gone
      refute_unread_count(parent_session)
    end
  end
end
