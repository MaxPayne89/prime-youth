defmodule KlassHeroWeb.AboutLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "AboutLive" do
    test "renders peach hero with yellow families highlight", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "#mk-about-hero")
      assert has_element?(view, "#mk-about-hero h1", "To modernize how Berlin")
      assert has_element?(view, "#mk-about-hero h1 span.bg-hero-yellow-500", "families")
    end

    test "displays Built for Berlin Families section with three value cards", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/about")

      assert has_element?(view, "#mk-about-values")
      assert html =~ "Built for Berlin Families"
      assert html =~ "unique needs of Berlin&#39;s diverse families"

      # All three value cards
      assert html =~ "Safety First"
      assert html =~ "All instructors are background-checked and verified."
      assert html =~ "Sustainability"
      assert html =~ "Supporting local programs and eco-conscious practices."
      assert html =~ "Community"
      assert html =~ "Building connections between families and local instructors."

      # Yellow-bordered cards
      assert html =~ "border-hero-yellow-400"
    end

    test "displays 6-step vetting grid with watermark digits", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/about")

      assert has_element?(view, "#mk-about-vetting")
      assert html =~ "Every Hero. Every step."

      # All 6 step titles render
      assert html =~ "Identity &amp; Age Verification"
      assert html =~ "Experience Validation"
      assert html =~ "Extended Background Checks"
      assert html =~ "Video Screening"
      assert html =~ "Child Safeguarding Training"
      assert html =~ "Community Standards Agreement"
    end

    test "displays The Klass Hero Story section with 4 founder cards", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/about")

      assert has_element?(view, "#mk-about-story")
      assert html =~ "Built by parents and educators"

      # Story paragraphs
      assert html =~ "spent over a decade as a coach"
      assert html =~ "Max Pergl"
      assert html =~ "Konstantin Pergl"
      assert html =~ "Laurie Camargo"

      # Founder grid: 4 initials avatars
      for initials <- ~w(SC MP KP LC) do
        assert html =~ initials, "expected founder initials #{initials} to render"
      end
    end

    test "displays CTA section with primary + ghost buttons", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/about")

      assert has_element?(view, "#mk-about-cta")
      assert html =~ "Ready to join the movement?"
      assert html =~ "Get Started Today"
      assert html =~ "Talk to us"
      assert html =~ ~s(href="/users/register")
      assert html =~ ~s(href="/contact")
    end

    test "renders under :marketing chrome", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/about")

      # mk_header sticky + active highlight
      assert has_element?(view, "header.sticky nav a", "About")

      # mk_footer legal links
      assert html =~ "Impressum"
      assert html =~ "Datenschutz"
      assert html =~ "AGB"
    end

    test "page uses mobile-first responsive design", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "md:grid-cols-2"
      assert html =~ "lg:grid-cols-3"
    end
  end
end
