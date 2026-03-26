defmodule KlassHeroWeb.E2E.Messaging.DirectMessageTest do
  @moduledoc """
  E2E tests for direct message flows.

  Scenario 3: Provider sends a DM and parent receives it.
  Scenario 4: Parent replies to a DM and provider receives it.
  """

  use KlassHeroWeb.E2ECase

  alias KlassHero.Accounts.Scope
  alias KlassHero.Messaging
  alias KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries

  describe "direct messaging" do
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

      # Create direct conversation programmatically (no UI for this)
      provider_scope = Scope.for_user(provider_user) |> Scope.resolve_roles()

      {:ok, conversation} =
        Messaging.create_direct_conversation(provider_scope, provider.id, parent_user.id)

      {:ok, _message} =
        Messaging.send_message(
          conversation.id,
          provider_user.id,
          "Hello! Welcome to the program."
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
        conversation: conversation
      }
    end

    test "provider sends DM and parent receives it", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      # Provider opens the conversation and sees the initial message
      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> assert_message_visible("Hello! Welcome to the program.")

      # Provider sends a new message via the UI
      provider_session
      |> send_message("Don't forget to bring your homework!")

      # Wait for DB commit and rebuild summaries
      Process.sleep(500)
      ConversationSummaries.rebuild()

      # Parent navigates to the conversation to see the new message
      parent_session
      |> visit("/messages/#{conversation.id}")
      |> assert_message_visible("Don't forget to bring your homework!")
    end

    test "parent replies to DM and provider receives it", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      # Parent opens the conversation and sees the initial message
      parent_session
      |> visit("/messages/#{conversation.id}")
      |> assert_message_visible("Hello! Welcome to the program.")

      # Parent sends a reply via the UI
      parent_session
      |> send_message("Thanks! What time should we arrive?")

      # Wait for DB commit and rebuild summaries
      Process.sleep(500)
      ConversationSummaries.rebuild()

      # Provider navigates to the conversation to see the reply
      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> assert_message_visible("Thanks! What time should we arrive?")
    end
  end
end
