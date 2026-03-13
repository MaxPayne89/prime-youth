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

    test "non-admin is redirected from consent show page", %{conn: conn} do
      consent = insert(:consent_schema)

      assert {:error, {:redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/admin/consents/#{consent.id}/show")

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
      consent =
        insert(:consent_schema, consent_type: "medical")
        |> KlassHero.Repo.preload(:child)

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      assert has_element?(view, "td", consent.child.first_name)
      assert has_element?(view, "td", "Medical")
    end

    test "displays active status badge for active consent", %{conn: conn} do
      insert(:consent_schema, withdrawn_at: nil)
      {:ok, view, _html} = live(conn, ~p"/admin/consents")
      assert has_element?(view, "span", "Active")
    end

    test "displays withdrawn status badge for withdrawn consent", %{conn: conn} do
      insert(:consent_schema,
        withdrawn_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      {:ok, view, _html} = live(conn, ~p"/admin/consents")
      assert has_element?(view, "span", "Withdrawn")
    end

    test "displays compliance banner", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/consents")
      assert has_element?(view, "div.bg-blue-50", "append-only")
    end

    test "search by child name returns matching results", %{conn: conn} do
      consent =
        insert(:consent_schema, consent_type: "medical")
        |> KlassHero.Repo.preload(:child)

      other_consent =
        insert(:consent_schema, consent_type: "photo_marketing")
        |> KlassHero.Repo.preload(:child)

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      view
      |> element("form#index-search-form")
      |> render_change(%{"index_search" => %{"value" => consent.child.first_name}})

      assert has_element?(view, "td", consent.child.first_name)
      refute has_element?(view, "td", other_consent.child.first_name)
    end

    test "search by parent display name returns matching results", %{conn: conn} do
      consent =
        insert(:consent_schema)
        |> KlassHero.Repo.preload(:parent)

      other_consent =
        insert(:consent_schema)
        |> KlassHero.Repo.preload(:parent)

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      view
      |> element("form#index-search-form")
      |> render_change(%{"index_search" => %{"value" => consent.parent.display_name}})

      assert has_element?(view, "td", consent.parent.display_name)
      refute has_element?(view, "td", other_consent.parent.display_name)
    end

    test "consent type filter narrows results", %{conn: conn} do
      insert(:consent_schema, consent_type: "medical")
      insert(:consent_schema, consent_type: "photo_marketing")

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      view
      |> element("form[phx-change='change-filter']")
      |> render_change(%{"filters" => %{"consent_type" => "medical"}})

      assert has_element?(view, "td", "Medical")
      refute has_element?(view, "td", "Photo Marketing")
    end

    test "status filter shows only active consents", %{conn: conn} do
      insert(:consent_schema, withdrawn_at: nil)

      insert(:consent_schema,
        withdrawn_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      view
      |> element("form[phx-change='change-filter']")
      |> render_change(%{"filters" => %{"withdrawn_at" => "active"}})

      assert has_element?(view, "span", "Active")
      refute has_element?(view, "span", "Withdrawn")
    end

    test "status filter shows only withdrawn consents", %{conn: conn} do
      insert(:consent_schema, withdrawn_at: nil)

      insert(:consent_schema,
        withdrawn_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      {:ok, view, _html} = live(conn, ~p"/admin/consents")

      view
      |> element("form[phx-change='change-filter']")
      |> render_change(%{"filters" => %{"withdrawn_at" => "withdrawn"}})

      assert has_element?(view, "span", "Withdrawn")
      refute has_element?(view, "span", "Active")
    end
  end

  describe "consent show" do
    setup :register_and_log_in_admin

    test "displays consent type on show page", %{conn: conn} do
      consent = insert(:consent_schema, consent_type: "photo_marketing")
      {:ok, _view, html} = live(conn, ~p"/admin/consents/#{consent.id}/show")
      assert html =~ "Photo Marketing"
    end

    test "edit and delete buttons are not shown on show page", %{conn: conn} do
      consent = insert(:consent_schema)
      {:ok, view, _html} = live(conn, ~p"/admin/consents/#{consent.id}/show")
      refute has_element?(view, "a", "Edit")
      refute has_element?(view, "a", "Delete")
    end

    test "displays withdrawn status on show page", %{conn: conn} do
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
