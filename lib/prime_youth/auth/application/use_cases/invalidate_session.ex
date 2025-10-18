defmodule PrimeYouth.Auth.Application.UseCases.InvalidateSession do
  @moduledoc """
  Use case for session token invalidation (logout).
  Depends on Repository port.
  """

  def execute(token, repo \\ default_repo()) do
    repo.delete_session_token(token)
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
end
