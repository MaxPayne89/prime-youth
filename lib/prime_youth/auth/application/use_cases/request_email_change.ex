defmodule PrimeYouth.Auth.Application.UseCases.RequestEmailChange do
  @moduledoc """
  Use case for requesting an email change with token-based confirmation using monadic composition.

  This initiates the email change process by:
  1. Validating the new email address
  2. Checking if the email is available
  3. Generating a confirmation token
  4. Sending a confirmation email to the new address

  The email change is not completed until the user clicks the confirmation link.

  Depends on Repository and Notifier ports.
  """

  import Funx.Monad

  alias Funx.Monad.Either
  alias PrimeYouth.Auth.Domain.Models.User

  @type params :: %{
          user_id: integer(),
          new_email: String.t()
        }

  def execute(params, repo \\ default_repo(), notifier \\ default_notifier()) do
    # Validate new email by creating temporary user
    temp_user_result = User.make(params.new_email, first_name: "temp", last_name: "temp")

    temp_user_result
    |> map(fn temp_user -> User.email(temp_user) end)
    |> bind(fn validated_email ->
      find_and_validate_user(params.user_id, validated_email, repo)
    end)
    |> bind(fn {user, validated_email} ->
      check_email_available_either(user, validated_email, repo)
    end)
    |> bind(fn {user, validated_email} -> generate_token_either(user, validated_email, repo) end)
    |> bind(fn {user, validated_email, token} ->
      send_confirmation_either(user, validated_email, token, notifier)
    end)
    |> Either.to_result()
  end

  # Find user by ID and combine with validated email
  defp find_and_validate_user(user_id, validated_email, repo) do
    case repo.find_by_id(user_id) do
      {:ok, user} -> Either.right({user, validated_email})
      {:error, :not_found} -> Either.left(:user_not_found)
      {:error, reason} -> Either.left(reason)
    end
  end

  # Check if email is available (or belongs to current user)
  defp check_email_available_either(user, validated_email, repo) do
    case repo.find_by_email(validated_email) do
      {:error, :not_found} ->
        Either.right({user, validated_email})

      {:ok, existing_user} ->
        if User.id(existing_user) == User.id(user) do
          Either.right({user, validated_email})
        else
          Either.left(:email_taken)
        end
    end
  end

  # Generate email change token
  defp generate_token_either(user, validated_email, repo) do
    case repo.generate_email_token(user, :change_email) do
      {:ok, token} -> Either.right({user, validated_email, token})
      {:error, reason} -> Either.left(reason)
    end
  end

  # Send confirmation email
  defp send_confirmation_either(user, validated_email, token, notifier) do
    case notifier.send_email_change_confirmation(user, validated_email, token) do
      :ok -> Either.right(%{token: token, new_email: validated_email})
      {:error, reason} -> Either.left(reason)
    end
  end

  defp default_repo, do: Application.fetch_env!(:prime_youth, :repository)
  defp default_notifier, do: Application.fetch_env!(:prime_youth, :notifier)
end
