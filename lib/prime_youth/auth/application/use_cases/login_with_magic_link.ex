defmodule PrimeYouth.Auth.Application.UseCases.LoginWithMagicLink do
  @moduledoc """
  Use case for authentication via magic link token using monadic composition.
  Depends on Repository port.
  """

  import Funx.Monad

  alias Funx.Monad.Either
  alias PrimeYouth.Auth.Domain.Models.User

  def execute(token, repo \\ default_repo()) do
    with {:ok, user} <- repo.verify_email_token(token, :magic_link),
         :ok <- check_unconfirmed_with_password(user) do
      handle_confirmation(user, repo)
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
      User.authenticate(user, now)
      |> bind(fn authenticated_user -> save_user_either(authenticated_user, repo) end)
      |> bind(fn saved_user -> delete_magic_link_token_either(saved_user, repo) end)
      |> map(fn saved_user -> {saved_user, []} end)
      |> Either.to_result()
    else
      # Confirm user, mark as authenticated, delete magic link token, and expire all session tokens
      User.confirm(user, now)
      |> bind(fn confirmed_user -> User.authenticate(confirmed_user, now) end)
      |> bind(fn authenticated_user -> save_user_either(authenticated_user, repo) end)
      |> bind(fn saved_user -> delete_magic_link_token_either(saved_user, repo) end)
      |> bind(fn saved_user -> delete_all_session_tokens_either(saved_user, repo) end)
      |> map(fn saved_user -> {saved_user, []} end)
      |> Either.to_result()
    end
  end

  defp save_user_either(user, repo) do
    case repo.update(user) do
      {:ok, saved_user} -> Either.right(saved_user)
      {:error, reason} -> Either.left(reason)
    end
  end

  defp delete_magic_link_token_either(user, repo) do
    case repo.delete_email_tokens_for_user(user, :magic_link) do
      :ok -> Either.right(user)
      {:error, reason} -> Either.left(reason)
    end
  end

  defp delete_all_session_tokens_either(user, repo) do
    case repo.delete_all_session_tokens_for_user(user) do
      :ok -> Either.right(user)
      {:error, reason} -> Either.left(reason)
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
end
