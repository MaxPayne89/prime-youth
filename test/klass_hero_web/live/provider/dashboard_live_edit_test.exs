defmodule KlassHeroWeb.Provider.DashboardLiveEditTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_provider

  describe "edit profile page" do
    test "renders edit profile form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/edit")

      assert has_element?(view, "h1", "Edit Profile")
      assert has_element?(view, "#profile-form")
      assert has_element?(view, "#save-profile-btn")
    end

    test "renders back to dashboard link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/edit")

      assert has_element?(view, "a", "Back to Dashboard")
    end

    test "renders verification documents section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/edit")

      assert has_element?(view, "#verification-docs")
      assert has_element?(view, "#doc-upload-form")
      assert has_element?(view, "#doc-type-select")
    end

    test "renders description textarea with current value", %{conn: conn, provider: provider} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/edit")

      html = render(view)
      assert html =~ provider.description
    end

    test "validates profile on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/edit")

      view
      |> form("#profile-form", %{provider_profile_schema: %{description: "Updated bio"}})
      |> render_change()

      # Form should still be present (no crash)
      assert has_element?(view, "#profile-form")
    end

    test "saves profile and redirects to dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/edit")

      view
      |> form("#profile-form", %{provider_profile_schema: %{description: "My new description"}})
      |> render_submit()

      assert_redirect(view, ~p"/provider/dashboard")
    end

    test "displays existing verification documents", %{conn: conn, provider: provider} do
      # Create a verification document for this provider
      KlassHero.Factory.insert(:verification_document_schema,
        provider_id: provider.id,
        document_type: "business_registration",
        original_filename: "my_registration.pdf"
      )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/edit")

      assert has_element?(view, "#verification-docs")
      html = render(view)
      assert html =~ "my_registration.pdf"
    end

    test "renders document type selector with all valid types", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/edit")

      html = render(view)
      assert html =~ "Business Registration"
      assert html =~ "Insurance Certificate"
      assert html =~ "ID Document"
      assert html =~ "Tax Certificate"
    end

    test "renders upload doc button disabled when no file selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/edit")

      assert has_element?(view, "#upload-doc-btn[disabled]")
    end
  end

  describe "navigation" do
    test "navigating from dashboard to edit via link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      view |> element("a", "Edit Profile") |> render_click()

      assert_redirect(view, ~p"/provider/dashboard/edit")
    end
  end
end
