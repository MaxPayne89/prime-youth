defmodule PrimeYouth.Auth.UseCases.RequestPasswordReset do
  @moduledoc """
  Use case for initiating password reset flow by sending reset email.
  Depends on Repository and Notifier ports.
  """

  def execute(email, repo \\ default_repo(), notifier \\ default_notifier()) do
    # Always return :ok to prevent user enumeration
    case repo.find_by_email(email) do
      {:ok, user} ->
        with {:ok, token} <- repo.generate_password_reset_token(user),
             :ok <- notifier.send_password_reset_email(user, token) do
          :ok
        else
          _ -> :ok
        end

      {:error, :not_found} ->
        # Prevent user enumeration by still returning :ok
        :ok
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
  defp default_notifier, do: Application.fetch_env!(:prime_youth, :notifier)
end
