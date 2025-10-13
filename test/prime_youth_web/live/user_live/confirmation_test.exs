defmodule PrimeYouthWeb.UserLive.ConfirmationTest do
  use PrimeYouthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PrimeYouth.AuthFixtures

  alias PrimeYouth.Auth.Infrastructure.UserNotifier
  alias PrimeYouth.Auth.Queries

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), confirmed_user: user_fixture()}
  end

  describe "Confirm user" do
    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          UserNotifier.deliver_login_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      assert html =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed user", %{conn: conn, confirmed_user: user} do
      token =
        extract_user_token(fn url ->
          UserNotifier.deliver_login_instructions(user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/users/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          UserNotifier.deliver_login_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "User confirmed successfully"

      {:ok, confirmed_user} = Queries.get_user_by_id(user.id)
      assert confirmed_user.confirmed_at
      # we are logged in now
      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # log out, new conn
      conn = build_conn()

      {:error, {:redirect, %{to: redirect_path, flash: flash}}} =
        live(conn, ~p"/users/log-in/#{token}")

      assert redirect_path == "/users/log-in"
      assert flash["error"] == "The link is invalid or it has expired."
    end

    test "logs confirmed user in without changing confirmed_at", %{
      conn: conn,
      confirmed_user: user
    } do
      token =
        extract_user_token(fn url ->
          UserNotifier.deliver_login_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/log-in/#{token}")

      form = form(lv, "#login_form", %{"user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Welcome back!"

      {:ok, retrieved_user} = Queries.get_user_by_id(user.id)
      assert retrieved_user.confirmed_at == user.confirmed_at

      # log out, new conn
      conn = build_conn()

      {:error, {:redirect, %{to: redirect_path, flash: flash}}} =
        live(conn, ~p"/users/log-in/#{token}")

      assert redirect_path == "/users/log-in"
      assert flash["error"] == "The link is invalid or it has expired."
    end

    test "raises error for invalid token", %{conn: conn} do
      {:error, {:redirect, %{to: redirect_path, flash: flash}}} =
        live(conn, ~p"/users/log-in/invalid-token")

      assert redirect_path == "/users/log-in"
      assert flash["error"] == "The link is invalid or it has expired."
    end
  end
end
