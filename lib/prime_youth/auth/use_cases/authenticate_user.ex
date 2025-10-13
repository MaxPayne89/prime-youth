defmodule PrimeYouth.Auth.UseCases.AuthenticateUser do
  @moduledoc """
  Use case for email and password authentication.
  Depends on Repository and PasswordHasher ports.
  """

  alias PrimeYouth.Auth.Domain.User

  def execute(credentials, repo \\ default_repo(), hasher \\ default_hasher()) do
    with {:ok, user} <- repo.find_by_email(credentials.email),
         true <- hasher.verify(credentials.password, user.hashed_password),
         true <- User.confirmed?(user) do
      # Mark user as authenticated and update in repository
      authenticated_user = User.authenticate(user, DateTime.utc_now(:second))

      case repo.update(authenticated_user) do
        {:ok, updated_user} -> {:ok, updated_user}
        error -> error
      end
    else
      {:error, :not_found} -> {:error, :invalid_credentials}
      false -> {:error, :invalid_credentials}
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
  defp default_hasher, do: Application.fetch_env!(:prime_youth, :password_hasher)
end
