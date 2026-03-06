defmodule KlassHeroWeb.TrustSafetyLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "TrustSafetyLive" do
    test "renders trust and safety page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/trust-safety")

      assert has_element?(view, "h1", "TRUST & SAFETY")
    end

    test "displays hero section with shield icon", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "TRUST &amp; SAFETY"
      assert html =~ "bg-hero-pink-50"
      assert html =~ "hero-shield-check"
    end

    test "displays commitment to child safety section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "Our Commitment to Child Safety"
      assert html =~ "Protect children and families"
      assert html =~ "Vetted with Care"
    end

    test "displays all six verification steps", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "How We Verify Providers"
      assert html =~ "Identity &amp; Age Verification"
      assert html =~ "Experience Validation"
      assert html =~ "Extended Background Checks"
      assert html =~ "Video Screening"
      assert html =~ "Child Safeguarding Training"
      assert html =~ "Community Standards Agreement"
    end

    test "displays ongoing quality section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "Ongoing Quality"
      assert html =~ "bg-gray-900"
    end

    test "displays CTA with contact link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "Have Questions?"
      assert html =~ ~s(href="/contact")
    end

    test "displays closing tagline", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "Trust is earned. Safety is non-negotiable."
    end

    test "page uses mobile-first responsive design", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trust-safety")

      assert html =~ "md:grid-cols-2"
      assert html =~ "lg:grid-cols-3"
    end
  end
end
