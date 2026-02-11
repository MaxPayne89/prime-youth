defmodule KlassHero.Accounts.Application.UseCases.RegisterUser do
  @moduledoc """
  Use case for registering a new user.

  Orchestrates user creation and domain event dispatch.
  """

  alias KlassHero.Accounts.Domain.Events.UserEvents
  alias KlassHero.Accounts.User
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  @doc """
  Registers a new user with the given attributes.

  Returns:
  - `{:ok, %User{}}` on success (dispatches user_registered event)
  - `{:error, %Ecto.Changeset{}}` on validation failure
  """
  def execute(attrs) when is_map(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        DomainEventBus.dispatch(
          KlassHero.Accounts,
          UserEvents.user_registered(user, %{registration_source: :web})
        )

        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
