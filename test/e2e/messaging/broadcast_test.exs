defmodule KlassHeroWeb.E2E.Messaging.BroadcastTest do
  @moduledoc """
  E2E tests for broadcast messaging flows.

  Scenario 1: Provider broadcasts a message and parent sees it in their conversation list.
  Scenario 2: Parent replies privately to a broadcast and provider sees the private conversation.
  """

  use KlassHeroWeb.E2ECase

  alias KlassHero.Messaging.Adapters.Driven.Projections.ConversationSummaries

  describe "broadcast messaging" do
    setup %{sandbox_metadata: metadata} do
      # Start the ConversationSummaries projection for E2E tests.
      # It's disabled in test config (start_projections: false) because
      # it bootstraps outside the sandbox. In E2E tests with shared sandbox,
      # we start it after the sandbox is established so it can see test data.
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

      parent =
        insert(:parent_profile_schema,
          identity_id: parent_user.id,
          subscription_tier: "active"
        )

      # Create child linked to parent
      {child, _parent_schema} = insert_child_with_guardian(parent: parent)

      # Create program owned by provider
      program = insert(:program_schema, provider_id: provider.id)

      # Create enrollment linking parent to program
      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: parent.id,
        child_id: child.id,
        status: "confirmed"
      )

      # Start browser sessions
      provider_session = new_session(metadata)
      parent_session = new_session(metadata)

      # Log in both users
      provider_session = log_in(provider_session, provider_user)
      parent_session = log_in(parent_session, parent_user)

      %{
        provider_session: provider_session,
        parent_session: parent_session,
        program: program
      }
    end

    test "provider broadcasts message and parent sees it", %{
      provider_session: provider_session,
      parent_session: parent_session,
      program: program
    } do
      # Provider sends broadcast
      provider_session
      |> visit("/provider/programs/#{program.id}/broadcast")
      |> fill_in(Query.css("#content"), with: "Field trip tomorrow at 9am!")
      |> click(Query.button("Send Broadcast"))

      # Provider is redirected to the broadcast conversation
      assert_has(
        provider_session,
        Query.css("[data-role=message]", text: "Field trip tomorrow at 9am!")
      )

      # Rebuild conversation summaries read model so the broadcast appears
      # in conversation lists (broadcast_sent events don't yet emit the
      # integration events the CQRS projection listens to)
      ConversationSummaries.rebuild()

      # Parent navigates to conversation list and sees the broadcast
      parent_session
      |> visit_conversations(:parent)
      |> assert_has(
        Query.css("[data-role=conversation-card]", text: "Field trip tomorrow at 9am!")
      )
    end

    test "parent replies privately to broadcast and provider sees private conversation", %{
      provider_session: provider_session,
      parent_session: parent_session,
      program: program
    } do
      # Provider sends broadcast first
      provider_session
      |> visit("/provider/programs/#{program.id}/broadcast")
      |> fill_in(Query.css("#content"), with: "Reminder: bring sunscreen")
      |> click(Query.button("Send Broadcast"))

      # Wait for provider to be redirected to the broadcast conversation
      assert_has(
        provider_session,
        Query.css("[data-role=message]", text: "Reminder: bring sunscreen")
      )

      # Rebuild conversation summaries read model so the broadcast appears
      ConversationSummaries.rebuild()

      # Parent opens the broadcast conversation from the conversation list
      parent_session
      |> visit_conversations(:parent)
      |> open_conversation("Reminder: bring sunscreen")

      # Parent clicks "Reply privately"
      parent_session
      |> click(Query.button("Reply privately"))

      # Parent is now in a private conversation — send a reply
      parent_session
      |> send_message("Should we also bring lunch?")

      # Wait briefly for the message to be committed to DB
      Process.sleep(500)

      # Rebuild summaries so the private conversation with reply appears
      # in conversation lists (test event publishers don't use PubSub,
      # so the CQRS projection needs a manual refresh)
      ConversationSummaries.rebuild()

      # Provider navigates to their conversation list and sees the private reply
      provider_session
      |> visit_conversations(:provider)
      |> assert_has(
        Query.css("[data-role=conversation-card]", text: "Should we also bring lunch?")
      )
    end
  end
end
