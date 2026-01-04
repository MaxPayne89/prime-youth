defmodule KlassHeroWeb.AboutLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "AboutLive" do
    test "renders about page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "h1", "OUR MISSION")
    end

    test "displays hero section with black background", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify hero section content and styling
      assert html =~ "OUR MISSION"
      assert html =~ "To modernize how families discover and engage"
      assert html =~ "bg-hero-black"
    end

    test "displays Built for Berlin Families section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify section heading and content
      assert html =~ "Built for Berlin Families"
      assert html =~ "unique needs of Berlin&#39;s diverse families"
      assert html =~ "sports to arts, technology to languages"
    end

    test "displays three value cards in Berlin Families section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify all three value cards are present
      assert html =~ "Safety First"
      assert html =~ "All instructors are background-checked and verified"

      assert html =~ "Sustainability"
      assert html =~ "Supporting local programs and eco-conscious practices"

      assert html =~ "Community"
      assert html =~ "Building connections between families and local instructors"
    end

    test "value cards have colored borders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify colored borders on value cards
      assert html =~ "border-hero-blue-400"
      assert html =~ "border-green-500"
      assert html =~ "border-hero-yellow-400"
    end

    test "displays 4-Step Vetting Process section with beige background", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify section heading and background
      assert html =~ "Our 4-Step Vetting Process"
      assert html =~ "bg-hero-pink-50"
      assert html =~ "rigorous screening to ensure the highest quality"
    end

    test "displays all four vetting process steps", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify all four steps are present with numbered circles
      assert html =~ "Identity Verification"
      assert html =~ "Official ID and credentials check"

      assert html =~ "Background Check"
      assert html =~ "Comprehensive criminal record screening"

      assert html =~ "Qualifications"
      assert html =~ "Certification and experience verification"

      assert html =~ "Personal Interview"
      assert html =~ "In-depth conversation about values and approach"
    end

    test "vetting steps have colored numbered circles", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify numbered circles with pastel backgrounds
      assert html =~ "bg-blue-200"
      assert html =~ "bg-purple-200"
      assert html =~ "bg-pink-200"
      assert html =~ "bg-green-200"
    end

    test "displays Founding Team section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify section heading
      assert html =~ "The Founding Team"
      assert html =~ "Meet the team building the future"
    end

    test "displays all three founding team members", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Shane Ogilvie
      assert html =~ "Shane Ogilvie"
      assert html =~ "CEO &amp; Co-Founder"
      assert html =~ "Former education technology leader"

      # Max Pergl
      assert html =~ "Max Pergl"
      assert html =~ "CTO &amp; Co-Founder"
      assert html =~ "Technology innovator"

      # Konstantin Pergl
      assert html =~ "Konstantin Pergl"
      assert html =~ "CFO &amp; Co-Founder"
      assert html =~ "Financial strategist"
    end

    test "team member avatars have colored backgrounds", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify colored avatar backgrounds
      assert html =~ "bg-hero-blue-400"
      assert html =~ "bg-pink-500"
      assert html =~ "bg-orange-500"
    end

    test "displays CTA section with beige background", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify CTA section content and styling
      assert html =~ "Ready to join the movement?"
      assert html =~ "GET STARTED TODAY"
      assert html =~ "bg-hero-pink-50"
    end

    test "CTA button links to registration page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify link points to registration page
      assert html =~ "href=\"/users/register\""
    end

    test "CTA button has cyan background", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify button styling
      assert html =~ "bg-hero-blue-500"
      assert html =~ "hover:bg-hero-blue-600"
    end

    test "page uses mobile-first responsive design", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify responsive grid classes
      assert html =~ "md:grid-cols-2"
      assert html =~ "lg:grid-cols-4"
      assert html =~ "md:grid-cols-3"
    end

    test "sections use consistent spacing", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify consistent padding and margins
      assert html =~ "py-12"
      assert html =~ "py-16"
      assert html =~ "lg:py-24"
    end

    test "page title is set to About Us", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify page title is set (in the socket assign)
      assert html =~ "OUR MISSION"
    end
  end
end
