defmodule KlassHero.Accounts.Adapters.Driven.Persistence.Repositories.UserRepository do
  @moduledoc """
  Repository implementation for user persistence.

  Implements ForStoringUsers with domain entity mapping via UserMapper.
  Read-only operations — mutations go through use cases with Ecto schemas.

  Infrastructure errors (connection, query) are not caught — they crash
  and are handled by the supervision tree.
  """

  @behaviour KlassHero.Accounts.Domain.Ports.ForStoringUsers

  import Ecto.Query

  alias KlassHero.Accounts.Adapters.Driven.Persistence.Mappers.UserMapper
  alias KlassHero.Accounts.User
  alias KlassHero.Repo

  @impl true
  def get_by_id(user_id) when is_binary(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, UserMapper.to_domain(schema)}
    end
  end

  @impl true
  def get_by_email(email) when is_binary(email) do
    case Repo.get_by(User, email: email) do
      nil -> nil
      schema -> {:ok, UserMapper.to_domain(schema)}
    end
  end

  @impl true
  def exists?(user_id) when is_binary(user_id) do
    User
    |> where([u], u.id == ^user_id)
    |> Repo.exists?()
  end
end
