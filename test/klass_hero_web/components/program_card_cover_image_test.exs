defmodule KlassHeroWeb.ProgramCardCoverImageTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHeroWeb.ProgramComponents

  @base_program %{
    id: "test-123",
    title: "Art Adventures",
    description: "Explore creativity",
    category: "Arts",
    meeting_days: ["Monday"],
    meeting_start_time: ~T[15:00:00],
    meeting_end_time: ~T[17:00:00],
    age_range: "6-8 years",
    price: 120.0,
    period: "per month",
    spots_left: nil,
    gradient_class: "bg-gradient-to-br from-hero-blue-400 to-hero-blue-600",
    icon_name: "hero-paint-brush",
    cover_image_url: nil,
    is_online: false
  }

  describe "program_card cover image" do
    test "renders cover image when cover_image_url is present" do
      program = Map.put(@base_program, :cover_image_url, "https://example.com/cover.jpg")
      html = render_component(&ProgramComponents.program_card/1, program: program)

      assert html =~ ~s(src="https://example.com/cover.jpg")
      assert html =~ "object-cover"
      # Icon should NOT be rendered when cover image is present
      refute html =~ "hero-paint-brush"
    end

    test "renders gradient fallback when cover_image_url is nil" do
      html = render_component(&ProgramComponents.program_card/1, program: @base_program)

      refute html =~ "<img"
      assert html =~ "bg-gradient-to-br"
      assert html =~ "hero-paint-brush"
    end
  end
end
