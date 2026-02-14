defmodule KlassHeroWeb.UIComponentsTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHeroWeb.UIComponents

  describe "messages_indicator/1" do
    test "renders with default href to /messages" do
      html =
        render_component(&UIComponents.messages_indicator/1, %{
          unread_count: 0
        })

      assert html =~ ~s|href="/messages"|
    end

    test "renders with custom href" do
      html =
        render_component(&UIComponents.messages_indicator/1, %{
          unread_count: 0,
          href: ~p"/provider/messages"
        })

      assert html =~ ~s|href="/provider/messages"|
    end

    test "renders unread badge when count > 0" do
      html =
        render_component(&UIComponents.messages_indicator/1, %{
          unread_count: 5
        })

      assert html =~ "5"
    end

    test "caps unread badge at 99" do
      html =
        render_component(&UIComponents.messages_indicator/1, %{
          unread_count: 150
        })

      assert html =~ "99"
    end

    test "hides badge when unread count is 0" do
      html =
        render_component(&UIComponents.messages_indicator/1, %{
          unread_count: 0
        })

      refute html =~ "badge" or html =~ "bg-prime-magenta"
    end
  end
end
