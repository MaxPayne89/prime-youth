defmodule KlassHeroWeb.ParticipationComponentsTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHeroWeb.ParticipationComponents

  describe "participation_status/1" do
    test "renders :cancelled with red badge and x-circle icon" do
      html =
        render_component(&ParticipationComponents.participation_status/1,
          status: :cancelled,
          size: :sm
        )

      assert html =~ "bg-red-100"
      assert html =~ "hero-x-circle"
      assert html =~ "Cancelled"
    end
  end
end
