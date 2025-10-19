defmodule PrimeYouth.Auth.Application.UseCases.RegisterUser do
  @moduledoc """
  Use case for user registration using monadic composition.
  Depends on Repository, PasswordHasher, and Notifier ports.
  """

  import Funx.Monad

  alias Funx.Monad.Either
  alias PrimeYouth.Auth.Domain.Models.User

  def execute(
        params,
        repo \\ default_repo(),
        hasher \\ default_hasher(),
        notifier \\ default_notifier()
      ) do
    User.make(
      params[:email],
      first_name: params[:first_name],
      last_name: params[:last_name]
    )
    |> bind(fn user -> check_email_available_either(user, repo) end)
    |> bind(fn user -> hash_password_either(user, params[:password], hasher) end)
    |> bind(fn user -> save_user_either(user, repo) end)
    |> bind(fn user -> send_confirmation_either(user, repo, notifier) end)
    |> Either.to_result()
  end

  # Check if email is available and return Either with user
  defp check_email_available_either(user, repo) do
    case repo.find_by_email(User.email(user)) do
      {:error, :not_found} -> Either.right(user)
      {:ok, _existing_user} -> Either.left(:email_taken)
    end
  end

  # Hash password and update user, returning Either
  defp hash_password_either(user, password, hasher) do
    case hasher.hash(password) do
      {:ok, hashed_password} ->
        User.change(user, %{hashed_password: hashed_password})

      {:error, reason} ->
        Either.left(reason)
    end
  end

  # Save user to repository, returning Either
  defp save_user_either(user, repo) do
    case repo.save(user) do
      {:ok, saved_user} -> Either.right(saved_user)
      {:error, reason} -> Either.left(reason)
    end
  end

  # Send confirmation email and return user, returning Either
  defp send_confirmation_either(user, repo, notifier) do
    with {:ok, token} <- repo.generate_email_token(user, :confirmation),
         :ok <- notifier.send_confirmation_email(user, token) do
      Either.right(user)
    else
      {:error, reason} -> Either.left(reason)
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
  defp default_hasher, do: Application.fetch_env!(:prime_youth, :password_hasher)
  defp default_notifier, do: Application.fetch_env!(:prime_youth, :notifier)
end
