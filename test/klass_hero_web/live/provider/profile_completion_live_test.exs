defmodule KlassHeroWeb.Provider.ProfileCompletionLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "draft provider profile completion" do
    setup :register_and_log_in_draft_provider

    test "renders completion form with expected fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/complete-profile")

      assert has_element?(view, "#profile-completion-form")
      assert has_element?(view, ~s(input[name="provider_profile_schema[business_name]"]))
      assert has_element?(view, ~s(textarea[name="provider_profile_schema[description]"]))
    end

    test "pre-fills description from staff member bio", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/complete-profile")

      assert has_element?(
               view,
               ~s(textarea[name="provider_profile_schema[description]"])
             )

      # Verify the description field contains the staff member's bio
      html = render(view)
      assert html =~ "Experienced youth sports coach"
    end

    test "validates on change and shows errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/complete-profile")

      view
      |> form("#profile-completion-form", %{
        provider_profile_schema: %{business_name: "", description: ""}
      })
      |> render_change()

      assert has_element?(view, "#profile-completion-form")
    end

    test "submits successfully and redirects to dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/complete-profile")

      view
      |> form("#profile-completion-form", %{
        provider_profile_schema: %{
          business_name: "Youth Sports Academy",
          description: "Premier youth sports training",
          phone: "+1234567890"
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/provider/dashboard")
    end

    test "shows validation errors for empty required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/complete-profile")

      view
      |> form("#profile-completion-form", %{
        provider_profile_schema: %{business_name: "", description: ""}
      })
      |> render_submit()

      assert has_element?(view, "#profile-completion-form")
      assert has_element?(view, ~s([phx-feedback-for="provider_profile_schema[business_name]"]))
    end
  end

  describe "active provider visiting completion page" do
    setup :register_and_log_in_provider

    test "redirects to dashboard with info flash", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/provider/complete-profile")

      assert path == ~p"/provider/dashboard"
      assert flash["info"] =~ "already"
    end
  end
end
