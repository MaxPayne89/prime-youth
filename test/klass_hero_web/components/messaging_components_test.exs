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

  describe "contact_provider_button/1" do
    test "renders a button carrying program_id and provider_id as phx-values" do
      html =
        render_component(&MessagingComponents.contact_provider_button/1, %{
          program_id: "prog-42",
          provider_id: "prov-7",
          "phx-click": "contact_provider"
        })

      doc = LazyHTML.from_fragment(html)
      button = LazyHTML.query(doc, "button")

      assert Enum.count(button) == 1
      assert LazyHTML.attribute(button, "phx-click") == ["contact_provider"]
      assert LazyHTML.attribute(button, "phx-value-program-id") == ["prog-42"]
      assert LazyHTML.attribute(button, "phx-value-provider-id") == ["prov-7"]
      assert LazyHTML.text(button) =~ "Contact Provider"
    end
  end
end
