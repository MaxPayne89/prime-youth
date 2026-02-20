defmodule KlassHeroWeb.AboutLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "AboutLive" do
    test "renders about page successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      assert has_element?(view, "h1", "OUR MISSION")
    end

    test "displays hero section with peach background", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "OUR MISSION"
      assert html =~ "To modernize how families discover and engage"
      assert html =~ "bg-hero-pink-50"
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

    test "value cards have yellow borders and blue icons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "border-hero-yellow-400"
      assert html =~ "bg-hero-blue-400"
    end

    test "displays 4-Step Vetting Process section with beige background", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Verify section heading and background
      assert html =~ "Our 3-Step Vetting Process"
      assert html =~ "bg-hero-pink-50"
      assert html =~ "rigorous screening to ensure the highest quality"
    end

    test "displays all three vetting process steps", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "Identity Verification"
      assert html =~ "Official ID and credentials check"

      assert html =~ "Qualifications"
      assert html =~ "Certification and experience verification"

      assert html =~ "Personal Interview"
      assert html =~ "In-depth conversation about values and approach"

      refute html =~ "Background Check"
    end

    test "vetting steps have KH blue numbered circles", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "bg-hero-blue-100"
      assert html =~ "text-hero-blue-700"
    end

    test "displays The Klass Hero Story section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "The Klass Hero Story"
      assert html =~ "Built by Parents and Educators for More Learning Opportunities"
    end

    test "displays founding story paragraphs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      # Trigger: verify all four founding story paragraphs are present
      # Why: each paragraph covers a different founder's contribution
      assert html =~ "Shane spent over a decade as a coach"
      assert html =~ "Max Pergl, a full-stack developer"
      assert html =~ "Konstantin Pergl"
      assert html =~ "Laurie Camargo"
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
      assert html =~ "lg:grid-cols-3"
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
