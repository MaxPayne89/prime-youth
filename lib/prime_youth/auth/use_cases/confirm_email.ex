defmodule PrimeYouth.Auth.UseCases.ConfirmEmail do
  @moduledoc """
  Use case for email confirmation via token.
  Depends on Repository port.
  """

  alias PrimeYouth.Auth.Domain.User

  def execute(token, repo \\ default_repo()) do
    with {:ok, user} <- repo.verify_email_token(token, :confirmation),
         false <- User.confirmed?(user),
         confirmed_user = User.confirm(user, DateTime.utc_now(:second)),
         {:ok, saved_user} <- repo.update(confirmed_user),
         :ok <- repo.delete_email_tokens_for_user(saved_user, :confirmation) do
      {:ok, saved_user}
    else
      {:error, _} = error -> error
      true -> {:error, :already_confirmed}
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
end
