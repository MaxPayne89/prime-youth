defmodule PrimeYouth.Auth.Application.UseCases.UpdatePassword do
  @moduledoc """
  Use case for changing user password.
  Depends on Repository, PasswordHasher, and Notifier ports.
  """

  def execute(
        params,
        repo \\ default_repo(),
        hasher \\ default_hasher(),
        notifier \\ default_notifier()
      ) do
    with {:ok, user} <- repo.find_by_id(params.user_id),
         true <- hasher.verify(params.current_password, user.hashed_password),
         {:ok, new_hashed} <- hasher.hash(params.new_password),
         {:ok, updated_user} <- repo.update_password(user, new_hashed),
         :ok <- repo.delete_all_session_tokens_for_user(updated_user),
         :ok <- notifier.send_password_change_notification(updated_user) do
      {:ok, updated_user}
    else
      {:error, :not_found} -> {:error, :user_not_found}
      false -> {:error, :invalid_password}
      {:error, _} = error -> error
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
  defp default_hasher, do: Application.fetch_env!(:prime_youth, :password_hasher)
  defp default_notifier, do: Application.fetch_env!(:prime_youth, :notifier)
end
