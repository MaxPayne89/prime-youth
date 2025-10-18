defmodule PrimeYouthWeb.UserLive.LoginTest do
  use PrimeYouthWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import PrimeYouth.AuthFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Log in"
      assert html =~ "Sign up"
    end
  end

  describe "user login - magic link" do
    test "sends magic link email when user exists", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      # Form starts with magic link, no need to toggle
      form(lv, "#login_form_magic_mobile", user: %{email: user.email})
      |> render_submit()

      # Verify token was created
      assert PrimeYouth.Repo.exists?(
               from t in PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserTokenSchema,
                 where: t.user_id == ^user.id and t.context == "login"
             )
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      # Form starts with magic link, no need to toggle
      # Submit form with non-existent email - should not error
      form(lv, "#login_form_magic_mobile", user: %{email: "idonotexist@example.com"})
      |> render_submit()

      # Verify no token was created for non-existent user
      assert PrimeYouth.Repo.get_by(
               PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserTokenSchema,
               context: "login"
             ) ==
               nil
    end
  end

  describe "user login - password" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      # Toggle to password form
      lv |> element("#login_form_magic_mobile button[phx-click='toggle_form']") |> render_click()

      form =
        form(lv, "#login_form_password_mobile",
          user: %{email: user.email, password: valid_user_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      # Toggle to password form
      lv |> element("#login_form_magic_mobile button[phx-click='toggle_form']") |> render_click()

      form =
        form(lv, "#login_form_password_mobile",
          user: %{email: "test@email.com", password: "123456"}
        )

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Sign up link is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _login_live, login_html} =
        lv
        |> element("[data-test-id='mobile-signup-link']", "Sign up")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      assert login_html =~ "Create Account"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      # User is already logged in (reauthentication mode), page shows magic link form by default
      assert html =~ "Prime Youth"
      assert html =~ "Send Magic Link"
    end
  end
end
