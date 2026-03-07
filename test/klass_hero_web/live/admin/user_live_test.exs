defmodule KlassHeroWeb.Admin.UserLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "admin access control" do
    setup :register_and_log_in_admin

    test "admin can access /admin/users", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/users")
      assert html =~ "Users"
    end
  end

  describe "non-admin access control" do
    setup :register_and_log_in_user

    test "non-admin is redirected from /admin/users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users")
    end
  end

  describe "unauthenticated access control" do
    test "unauthenticated user is redirected from /admin/users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/users")
    end
  end

  describe "user list" do
    setup :register_and_log_in_admin

    test "displays users in the table", %{conn: conn, user: admin} do
      regular_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Regular Test User"})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Backpex renders table data after connected mount via handle_params
      assert has_element?(view, "td", admin.email)
      assert has_element?(view, "td", admin.name)
      assert has_element?(view, "td", regular_user.email)
      assert has_element?(view, "td", regular_user.name)
    end
  end

  describe "edit user" do
    setup :register_and_log_in_admin

    test "admin can update user name", %{conn: conn} do
      target_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Original Name"})

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{target_user.id}/edit")

      # Backpex form targets a LiveComponent (phx-target="1").
      # The submit button has name="save-type" value="save" which must be
      # included in the submit params. Use render_submit with the submitter
      # option to include the button's value.
      view
      |> form("#resource-form", %{change: %{name: "Updated Name"}})
      |> render_submit(%{"save-type" => "save"})

      updated = KlassHero.Repo.get!(KlassHero.Accounts.User, target_user.id)
      assert updated.name == "Updated Name"
    end

    test "admin can toggle is_admin flag", %{conn: conn} do
      target_user = KlassHero.AccountsFixtures.user_fixture(%{name: "Toggle Target"})
      assert target_user.is_admin == false

      {:ok, view, _html} = live(conn, ~p"/admin/users/#{target_user.id}/edit")

      view
      |> form("#resource-form", %{change: %{is_admin: true}})
      |> render_submit(%{"save-type" => "save"})

      updated = KlassHero.Repo.get!(KlassHero.Accounts.User, target_user.id)
      assert updated.is_admin == true
    end
  end
end
