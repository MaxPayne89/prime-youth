defmodule KlassHero.Accounts.Application.UseCases.RegisterUser do
  @moduledoc """
  Use case for registering a new user.

  Orchestrates user creation via the repository and domain event dispatch.
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Shared.EventDispatchHelper

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
        |> EventDispatchHelper.dispatch(KlassHero.Accounts)

        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
