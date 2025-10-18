defmodule PrimeYouth.Auth.Application.UseCases.UpdateEmail do
  @moduledoc """
  Use case for changing user email address.
  Depends on Repository, PasswordHasher, and Notifier ports.
  """

  alias PrimeYouth.Auth.Domain.Models.User

  def execute(
        params,
        repo \\ default_repo(),
        hasher \\ default_hasher(),
        notifier \\ default_notifier()
      ) do
    with {:ok, user} <- repo.find_by_id(params.user_id),
         true <- hasher.verify(params.current_password, user.hashed_password),
         {:ok, updated_user} <- User.update_email(user, params.new_email),
         :ok <- check_email_available(updated_user.email, repo, user.id),
         {:ok, saved_user} <- repo.update_email(updated_user, updated_user.email),
         :ok <- notifier.send_email_change_notification(saved_user, user.email) do
      {:ok, saved_user}
    else
      {:error, :not_found} -> {:error, :user_not_found}
      false -> {:error, :invalid_password}
      {:error, :email_taken} = error -> error
      {:error, _} = error -> error
    end
  end

  defp check_email_available(email, repo, current_user_id) do
    case repo.find_by_email(email) do
      {:error, :not_found} ->
        :ok

      {:ok, existing_user} ->
        if existing_user.id == current_user_id do
          :ok
        else
          {:error, :email_taken}
        end
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
  defp default_hasher, do: Application.fetch_env!(:prime_youth, :password_hasher)
  defp default_notifier, do: Application.fetch_env!(:prime_youth, :notifier)
end
