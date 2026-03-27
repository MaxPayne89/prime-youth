defmodule KlassHeroWeb.E2E.Messaging.MarkAsReadTest do
  @moduledoc """
  E2E test for mark-as-read flow.

  Scenario 7: Opening a conversation marks messages as read and clears the unread badge.
  """

  use KlassHeroWeb.E2ECase

  describe "mark as read" do
    setup %{sandbox_metadata: metadata} do
      %{parent_user: parent_user} =
        setup_dm_conversation("Please confirm your child's attendance.")

      parent_session = new_session(metadata) |> log_in(parent_user)

      %{parent_session: parent_session}
    end

    test "opening conversation marks messages as read", %{
      parent_session: parent_session
    } do
      parent_session
      |> visit_conversations(:parent)
      |> assert_unread_count(1)

      parent_session
      |> open_conversation("Please confirm your child's attendance.")

      assert_message_visible(parent_session, "Please confirm your child's attendance.")

      # mark_as_read fires on connected mount — wait for it to complete
      wait_and_rebuild_summaries()

      parent_session
      |> visit_conversations(:parent)

      refute_unread_count(parent_session)
    end
  end
end
