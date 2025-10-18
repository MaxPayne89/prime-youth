defmodule PrimeYouth.Auth.Application.UseCases.LoginWithMagicLink do
  @moduledoc """
  Use case for authentication via magic link token.
  Depends on Repository port.
  """

  alias PrimeYouth.Auth.Domain.Models.User

  def execute(token, repo \\ default_repo()) do
    with {:ok, user} <- repo.verify_email_token(token, :magic_link),
         :ok <- check_unconfirmed_with_password(user) do
      result = handle_confirmation(user, repo)
      result
    end
  end

  defp check_unconfirmed_with_password(user) do
    if not User.confirmed?(user) and user.hashed_password != nil do
      {:error, :unconfirmed_with_password}
    else
      :ok
    end
  end

  defp handle_confirmation(user, repo) do
    now = DateTime.utc_now(:second)

    if User.confirmed?(user) do
      # Already confirmed, just delete the magic link token and mark as authenticated
      authenticated_user = User.authenticate(user, now)

      with {:ok, saved_user} <- repo.update(authenticated_user),
           :ok <- repo.delete_email_tokens_for_user(saved_user, :magic_link) do
        {:ok, {saved_user, []}}
      end
    else
      # Confirm user, mark as authenticated, delete magic link token, and expire all session tokens
      confirmed_user =
        user
        |> User.confirm(now)
        |> User.authenticate(now)

      with {:ok, saved_user} <- repo.update(confirmed_user),
           :ok <- repo.delete_email_tokens_for_user(saved_user, :magic_link),
           :ok <- repo.delete_all_session_tokens_for_user(saved_user) do
        {:ok, {saved_user, []}}
      end
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
end
