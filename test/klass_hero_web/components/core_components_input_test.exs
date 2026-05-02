defmodule KlassHeroWeb.CoreComponentsInputTest do
  @moduledoc """
  Tests for the `pill` and `icon` attrs added to `CoreComponents.input/1`
  during Phase 0 of the design-handoff migration. These attrs let consumers
  render the `KhInput pill icon="search"` variant from the design bundle
  (Primitives.jsx:147) without authoring bespoke search-input markup.
  """

  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHeroWeb.CoreComponents

  describe "input/1 default text input" do
    test "renders rounded-lg corners by default" do
      html =
        render_component(&CoreComponents.input/1, %{
          name: "q",
          value: "",
          type: "text"
        })

      assert html =~ "rounded-lg"
      refute html =~ "rounded-full"
      refute html =~ "hero-magnifying-glass"
    end

    test "renders rounded-full corners when pill=true" do
      html =
        render_component(&CoreComponents.input/1, %{
          name: "q",
          value: "",
          type: "text",
          pill: true
        })

      assert html =~ "rounded-full"
      refute html =~ "rounded-lg"
    end

    test "renders a leading icon when icon is set" do
      html =
        render_component(&CoreComponents.input/1, %{
          name: "q",
          value: "",
          type: "text",
          icon: "hero-magnifying-glass"
        })

      assert html =~ "hero-magnifying-glass"
      assert html =~ "pl-10"
    end

    test "combines pill and icon" do
      html =
        render_component(&CoreComponents.input/1, %{
          name: "q",
          value: "",
          type: "text",
          pill: true,
          icon: "hero-magnifying-glass"
        })

      assert html =~ "rounded-full"
      assert html =~ "hero-magnifying-glass"
      assert html =~ "pl-10"
    end
  end
end
