defmodule PrimeYouth.Auth.Application.UseCases.CreateSession do
  @moduledoc """
  Use case for session token generation after authentication.
  Depends on Repository port.
  """

  alias PrimeYouth.Auth.Domain.Models.User

  def execute(%User{} = user, repo \\ default_repo()) do
    repo.generate_session_token(user)
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
end
