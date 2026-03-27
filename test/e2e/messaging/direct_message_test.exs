defmodule KlassHeroWeb.E2E.Messaging.DirectMessageTest do
  @moduledoc """
  E2E tests for direct message flows.

  Scenario 3: Provider sends a DM and parent receives it.
  Scenario 4: Parent replies to a DM and provider receives it.
  """

  use KlassHeroWeb.E2ECase

  describe "direct messaging" do
    setup %{sandbox_metadata: metadata} do
      %{conversation: conversation} =
        data = setup_dm_conversation("Hello! Welcome to the program.")

      provider_session = new_session(metadata) |> log_in(data.provider_user)
      parent_session = new_session(metadata) |> log_in(data.parent_user)

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
      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> assert_message_visible("Hello! Welcome to the program.")

      provider_session |> send_message("Don't forget to bring your homework!")

      wait_and_rebuild_summaries()

      parent_session
      |> visit("/messages/#{conversation.id}")
      |> assert_message_visible("Don't forget to bring your homework!")
    end

    test "parent replies to DM and provider receives it", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      parent_session
      |> visit("/messages/#{conversation.id}")
      |> assert_message_visible("Hello! Welcome to the program.")

      parent_session |> send_message("Thanks! What time should we arrive?")

      wait_and_rebuild_summaries()

      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> assert_message_visible("Thanks! What time should we arrive?")
    end
  end
end
