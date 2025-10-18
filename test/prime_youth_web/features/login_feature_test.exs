defmodule PrimeYouthWeb.Features.LoginFeatureTest do
  @moduledoc """
  Feature test for user login flow using phoenix_test.
  Demonstrates the user-centric testing approach.
  """

  use PrimeYouthWeb.FeatureCase, async: true

  import Ecto.Query

  describe "user login journey" do
    test "user can log in with magic link", %{conn: conn} do
      user = user_fixture()

      conn
      |> visit("/users/log-in")
      |> assert_has("h2", text: "Welcome Back")
      |> within("#login_form_magic_mobile", fn session ->
        session
        |> fill_in("Email", with: user.email)
        |> click_button("Send Magic Link")
      end)
      |> assert_has("[role='alert']", text: "If your email is in our system")

      # Verify token was created
      assert PrimeYouth.Repo.exists?(
               from t in PrimeYouth.Auth.Adapters.Driven.Persistence.Schemas.UserSchemaToken,
                 where: t.user_id == ^user.id and t.context == "login"
             )
    end

    # Password login tests are in login_test.exs using LiveViewTest
    # phoenix_test cannot handle duplicate forms (mobile + desktop) with phx-trigger-action
    test "user can toggle to password form", %{conn: conn} do
      conn
      |> visit("/users/log-in")
      |> assert_has("button", text: "Send Magic Link")
      |> click_button("Or use password")
      |> assert_has("button", text: "Sign In")
      |> assert_has("input[type='password']")
    end

    test "user can navigate to registration from login", %{conn: conn} do
      conn
      |> visit("/users/log-in")
      |> click_link("Sign up")
      |> assert_path("/users/register")
      |> assert_has("h2", text: "Create Account")
    end
  end

  describe "authenticated user experience" do
    test "already logged in user sees reauthentication prompt", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      conn
      |> visit("/users/log-in")
      |> assert_has("p", text: "You need to reauthenticate")
      |> refute_has("a", text: "Register")
      |> assert_has("input[value='#{user.email}']")
    end
  end
end
