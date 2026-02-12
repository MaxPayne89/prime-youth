defmodule KlassHero.Accounts.Application.UseCases.RegisterUser do
  @moduledoc """
  Use case for registering a new user.

  Orchestrates user creation via the repository and domain event dispatch.
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @user_repository Application.compile_env!(
                     :klass_hero,
                     [:accounts, :for_storing_users]
                   )

  @doc """
  Registers a new user with the given attributes.

  Returns:
  - `{:ok, %User{}}` on success (dispatches user_registered event)
  - `{:error, %Ecto.Changeset{}}` on validation failure
  """
  def execute(attrs) when is_map(attrs) do
    case @user_repository.register(attrs) do
      {:ok, user} ->
        UserEvents.user_registered(user, %{registration_source: :web})
        |> dispatch_event(:user_registered)

        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
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
