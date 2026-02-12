defmodule KlassHero.Accounts.Application.UseCases.ChangeEmail do
  @moduledoc """
  Use case for updating a user's email via confirmation token.

  Orchestrates the email change flow via the repository and
  dispatches the user_email_changed domain event.
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Shared.EventDispatchHelper

  @user_repository Application.compile_env!(
                     :klass_hero,
                     [:accounts, :for_storing_users]
                   )

  @doc """
  Updates the user's email using the given confirmation token.

  Returns:
  - `{:ok, %User{}}` on success
  - `{:error, :invalid_token}` if token is invalid or expired
  - `{:error, changeset}` if email update fails
  """
  def execute(%{email: _} = user, token) when is_binary(token) do
    previous_email = user.email

    case @user_repository.apply_email_change(user, token) do
      {:ok, updated_user} ->
        UserEvents.user_email_changed(updated_user, %{previous_email: previous_email})
        |> EventDispatchHelper.dispatch(KlassHero.Accounts)

        {:ok, updated_user}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
