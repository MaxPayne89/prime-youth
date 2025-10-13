defmodule PrimeYouthWeb.UserSessionController do
  use PrimeYouthWeb, :controller

  alias PrimeYouth.Auth.UseCases.{AuthenticateUser, LoginWithMagicLink, UpdatePassword}
  alias PrimeYouthWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token}} = params, info) do
    case LoginWithMagicLink.execute(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"user" => user_params} = params, info) do
    %{"email" => email, "password" => password} = user_params

    case AuthenticateUser.execute(%{email: email, password: password}) do
      {:ok, user} ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, params)

      _ ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        conn
        |> put_flash(:error, "Invalid email or password")
        |> put_flash(:email, String.slice(email, 0, 160))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user

    case UpdatePassword.execute(%{
           user_id: user.id,
           current_password: user_params["current_password"],
           new_password: user_params["password"]
         }) do
      {:ok, _updated_user} ->
        conn
        |> put_session(:user_return_to, ~p"/users/settings")
        |> create(
          Map.put(params, "force_session_renewal", true),
          "Password updated successfully!"
        )

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Failed to update password")
        |> redirect(to: ~p"/users/settings")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
