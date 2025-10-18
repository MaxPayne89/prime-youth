defmodule PrimeYouth.Auth.Application.UseCases.RequestEmailChange do
  @moduledoc """
  Use case for requesting an email change with token-based confirmation.

  This initiates the email change process by:
  1. Validating the new email address
  2. Checking if the email is available
  3. Generating a confirmation token
  4. Sending a confirmation email to the new address

  The email change is not completed until the user clicks the confirmation link.

  Depends on Repository and Notifier ports.
  """

  alias PrimeYouth.Auth.Domain.Models.User

  @type params :: %{
          user_id: integer(),
          new_email: String.t()
        }

  def execute(params, repo \\ default_repo(), notifier \\ default_notifier()) do
    with {:ok, user} <- repo.find_by_id(params.user_id),
         {:ok, validated_email} <- User.validate_email(params.new_email),
         :ok <- check_email_available(validated_email, repo, user.id),
         {:ok, token} <- repo.generate_email_token(user, :change_email),
         :ok <- notifier.send_email_change_confirmation(user, validated_email, token) do
      {:ok, %{token: token, new_email: validated_email}}
    else
      {:error, :not_found} -> {:error, :user_not_found}
      {:error, :email_taken} = error -> error
      {:error, :email_required} -> {:error, :invalid_email}
      {:error, :email_too_long} -> {:error, :invalid_email}
      {:error, :invalid_email_format} -> {:error, :invalid_email}
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
  defp default_notifier, do: Application.fetch_env!(:prime_youth, :notifier)
end
