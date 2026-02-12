defmodule KlassHero.Accounts.Application.UseCases.ChangeEmail do
  @moduledoc """
  Use case for updating a user's email via confirmation token.

  Orchestrates the email change flow via the repository and
  dispatches the user_email_changed domain event.
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Accounts.User
  alias KlassHero.Shared.DomainEventBus

  require Logger

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
  def execute(%User{} = user, token) when is_binary(token) do
    previous_email = user.email

    case @user_repository.apply_email_change(user, token) do
      {:ok, updated_user} ->
        UserEvents.user_email_changed(updated_user, %{previous_email: previous_email})
        |> dispatch_event(:user_email_changed)

        {:ok, updated_user}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch_event(event, event_type) do
    case DomainEventBus.dispatch(KlassHero.Accounts, event) do
      :ok ->
        :ok

      {:error, failures} ->
        Logger.warning("Event dispatch failed",
          event_type: event_type,
          failures: inspect(failures)
        )
    end
  end
end
