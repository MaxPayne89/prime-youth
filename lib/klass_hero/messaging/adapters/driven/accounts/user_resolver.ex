defmodule KlassHero.Messaging.Adapters.Driven.Accounts.UserResolver do
  @moduledoc """
  Adapter for resolving user display information from the Accounts bounded context.

  This adapter queries the Accounts context to get user names for
  displaying in messaging UI (participant names, sender names).
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForResolvingUsers

  import Ecto.Query

  alias KlassHero.Accounts.User
  alias KlassHero.Repo

  @impl true
  @spec get_display_names([String.t()]) :: {:ok, %{String.t() => String.t()}}
  def get_display_names([]), do: {:ok, %{}}

  def get_display_names(user_ids) do
    names_map =
      from(u in User,
        where: u.id in ^user_ids,
        select: {u.id, u.name, u.email}
      )
      |> Repo.all()
      |> Map.new(fn {id, name, email} -> {id, name || email} end)

    {:ok, names_map}
  end

  @impl true
  @spec get_display_name(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_display_name(user_id) do
    case Repo.one(from(u in User, where: u.id == ^user_id, select: {u.name, u.email})) do
      nil -> {:error, :not_found}
      {name, email} -> {:ok, name || email}
    end
  end

  @impl true
  @spec get_user_id_for_provider(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_user_id_for_provider(provider_id) do
    # Trigger: need identity_id for a provider_id stored on a conversation
    # Why: delegate to Provider facade to respect bounded context boundaries —
    #      Messaging is not allowed to query Provider schemas directly
    # Outcome: returns the user ID (identity_id) for permission checks
    KlassHero.Provider.get_identity_id_for_provider(provider_id)
  end
end
