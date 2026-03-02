defmodule KlassHeroWeb.MessagingComponentsTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHeroWeb.MessagingComponents

  describe "conversation_card/1" do
    test "renders with nil other_participant_name without crashing" do
      html =
        render_component(&MessagingComponents.conversation_card/1, %{
          id: "conv-test",
          conversation: %{id: "conv-1", type: :direct},
          unread_count: 0,
          latest_message: nil,
          other_participant_name: nil
        })

      assert html =~ "Unknown"
    end

    test "renders the provided participant name" do
      html =
        render_component(&MessagingComponents.conversation_card/1, %{
          id: "conv-test",
          conversation: %{id: "conv-1", type: :direct},
          unread_count: 0,
          latest_message: nil,
          other_participant_name: "Jane Doe"
        })

      assert html =~ "Jane Doe"
    end
  end
end
