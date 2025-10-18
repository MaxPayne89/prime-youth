defmodule PrimeYouth.Auth.Application.UseCases.SendMagicLink do
  @moduledoc """
  Use case for sending magic link email for passwordless login.
  Depends on Repository and Notifier ports.
  """

  def execute(email, repo \\ default_repo(), notifier \\ default_notifier()) do
    # Always return :ok to prevent user enumeration
    case repo.find_by_email(email) do
      {:ok, user} ->
        with {:ok, token} <- repo.generate_email_token(user, :magic_link),
             :ok <- notifier.send_magic_link_email(user, token) do
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
