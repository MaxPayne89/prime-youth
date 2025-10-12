defmodule PrimeYouth.Auth.UseCases.RegisterUser do
  @moduledoc """
  Use case for user registration.
  Depends on Repository, PasswordHasher, and Notifier ports.
  """

  alias PrimeYouth.Auth.Domain.User

  def execute(
        params,
        repo \\ default_repo(),
        hasher \\ default_hasher(),
        notifier \\ default_notifier()
      ) do
    with {:ok, user} <- User.new(params),
         :ok <- check_email_available(user.email, repo),
         {:ok, hashed} <- hasher.hash(params[:password]),
         user = %{user | hashed_password: hashed},
         {:ok, saved_user} <- repo.save(user),
         {:ok, token} <- repo.generate_email_token(saved_user, :confirmation),
         :ok <- notifier.send_confirmation_email(saved_user, token) do
      {:ok, saved_user}
    else
      {:error, :email_taken} = error -> error
      {:error, _} = error -> error
    end
  end

  defp check_email_available(email, repo) do
    case repo.find_by_email(email) do
      {:error, :not_found} -> :ok
      {:ok, _user} -> {:error, :email_taken}
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
  defp default_hasher, do: Application.fetch_env!(:prime_youth, :password_hasher)
  defp default_notifier, do: Application.fetch_env!(:prime_youth, :notifier)
end
