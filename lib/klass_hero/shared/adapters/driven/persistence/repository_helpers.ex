defmodule KlassHero.Shared.Adapters.Driven.Persistence.RepositoryHelpers do
  @moduledoc """
  Shared query helpers for repository adapters across bounded contexts.

  Provides common fetch-and-map patterns that eliminate boilerplate in
  repository implementations. Delegates data transformation to the
  mapper module passed by the caller.
  """

  @doc """
  Fetches a record by primary key and maps it to a domain struct.

  The mapper module must implement `to_domain/1`.

  ## Examples

      iex> RepositoryHelpers.get_by_id(UserSchema, "a1b2c3d4-e5f6-7890-abcd-ef1234567890", UserMapper)
      {:ok, %User{}}

      iex> RepositoryHelpers.get_by_id(UserSchema, "00000000-0000-0000-0000-000000000000", UserMapper)
      {:error, :not_found}

  """
  @spec get_by_id(module(), term(), module()) :: {:ok, struct()} | {:error, :not_found}
  def get_by_id(schema, id, mapper) do
    case KlassHero.Repo.get(schema, id) do
      nil -> {:error, :not_found}
      record -> {:ok, mapper.to_domain(record)}
    end
  end
end
