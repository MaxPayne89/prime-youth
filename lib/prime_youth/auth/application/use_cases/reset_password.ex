defmodule PrimeYouth.Auth.Application.UseCases.ResetPassword do
  @moduledoc """
  Use case for completing password reset with token and new password.
  Depends on Repository and PasswordHasher ports.
  """

  def execute(token, new_password, repo \\ default_repo(), hasher \\ default_hasher()) do
    with {:ok, user} <- repo.verify_password_reset_token(token),
         {:ok, hashed} <- hasher.hash(new_password),
         {:ok, updated_user} <- repo.update_password(user, hashed),
         :ok <- repo.delete_all_session_tokens_for_user(updated_user),
         :ok <- repo.delete_password_reset_tokens_for_user(updated_user) do
      {:ok, updated_user}
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
  defp default_hasher, do: Application.fetch_env!(:prime_youth, :password_hasher)
end
