defmodule PrimeYouth.Auth.Application.UseCases.AuthenticateUser do
  @moduledoc """
  Use case for email and password authentication using monadic composition.
  Depends on Repository and PasswordHasher ports.
  """

  import Funx.Monad

  alias Funx.Monad.Either
  alias PrimeYouth.Auth.Domain.Models.User

  def execute(credentials, repo \\ default_repo(), hasher \\ default_hasher()) do
    with {:ok, user} <- repo.find_by_email(credentials.email),
         true <- hasher.verify(credentials.password, user.hashed_password),
         true <- User.confirmed?(user) do
      # Mark user as authenticated and update in repository
      User.authenticate(user, DateTime.utc_now(:second))
      |> bind(fn authenticated_user -> save_user_either(authenticated_user, repo) end)
      |> Either.to_result()
    else
      {:error, :not_found} -> {:error, :invalid_credentials}
      false -> {:error, :invalid_credentials}
    end
  end

  defp save_user_either(user, repo) do
    case repo.update(user) do
      {:ok, saved_user} -> Either.right(saved_user)
      {:error, reason} -> Either.left(reason)
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
  defp default_hasher, do: Application.fetch_env!(:prime_youth, :password_hasher)
end
