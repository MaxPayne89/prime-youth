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
        select: {u.id, u.name}
      )
      |> Repo.all()
      |> Map.new()

    {:ok, names_map}
  end

  @impl true
  @spec get_display_name(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_display_name(user_id) do
    case Repo.one(from(u in User, where: u.id == ^user_id, select: u.name)) do
      nil -> {:error, :not_found}
      name -> {:ok, name}
    end
  end
end
