defmodule KlassHeroWeb.Admin.ConsentLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/consents", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/consents")
      assert html =~ "Consents"
    end

    test "new consent button is not shown on index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")
      refute has_element?(view, "a", "New")
    end
  end

  describe "non-admin access control" do
    setup :register_and_log_in_user

    test "non-admin is redirected from /admin/consents", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/admin/consents")

      assert flash["error"] =~ "access"
    end
  end

  describe "unauthenticated access control" do
    test "unauthenticated user is redirected from /admin/consents", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/admin/consents")
    end
  end

  describe "consent list" do
    setup :register_and_log_in_admin

    test "displays consent records in the table", %{conn: conn} do
      consent = insert(:consent_schema, consent_type: "medical")

      child =
        KlassHero.Repo.get!(
          KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema,
          consent.child_id
        )

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      assert has_element?(view, "td", child.first_name)
      assert has_element?(view, "td", "Medical")
    end

    test "displays active status badge for active consent", %{conn: conn} do
      insert(:consent_schema, withdrawn_at: nil)
      {:ok, _view, html} = live(conn, ~p"/admin/consents")
      assert html =~ "Active"
    end

    test "displays withdrawn status badge for withdrawn consent", %{conn: conn} do
      insert(:consent_schema,
        withdrawn_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      {:ok, _view, html} = live(conn, ~p"/admin/consents")
      assert html =~ "Withdrawn"
    end

    test "displays compliance banner", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/consents")
      assert html =~ "append-only"
    end

    test "search by child name returns matching results", %{conn: conn} do
      consent = insert(:consent_schema, consent_type: "medical")

      child =
        KlassHero.Repo.get!(
          KlassHero.Family.Adapters.Driven.Persistence.Schemas.ChildSchema,
          consent.child_id
        )

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      view
      |> element("form#index-search-form")
      |> render_change(%{"index_search" => %{"value" => child.first_name}})

      assert has_element?(view, "td", child.first_name)
    end

    test "search by parent display name returns matching results", %{conn: conn} do
      consent = insert(:consent_schema)

      parent =
        KlassHero.Repo.get!(
          KlassHero.Family.Adapters.Driven.Persistence.Schemas.ParentProfileSchema,
          consent.parent_id
        )

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      view
      |> element("form#index-search-form")
      |> render_change(%{"index_search" => %{"value" => parent.display_name}})

      assert has_element?(view, "td", parent.display_name)
    end
  end

  describe "consent show" do
    setup :register_and_log_in_admin

    test "displays consent detail with granted_at", %{conn: conn} do
      consent = insert(:consent_schema, consent_type: "photo_marketing")
      {:ok, _view, html} = live(conn, ~p"/admin/consents/#{consent.id}/show")
      assert html =~ "Photo Marketing"
    end

    test "displays withdrawn_at on show page", %{conn: conn} do
      withdrawn_at = ~U[2026-02-15 10:30:00Z]

      consent =
        insert(:consent_schema,
          consent_type: "medical",
          withdrawn_at: withdrawn_at
        )

      {:ok, _view, html} = live(conn, ~p"/admin/consents/#{consent.id}/show")
      assert html =~ "Withdrawn"
    end
  end
end
