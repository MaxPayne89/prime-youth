defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProviderProgramRepository do
  @moduledoc """
  Read-only repository for the provider_programs projection.

  Implements the ForQueryingProviderPrograms port. This repository only reads —
  the projection GenServer handles all writes.
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForQueryingProviderPrograms

  import Ecto.Query

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProgramProjectionSchema
  alias KlassHero.Provider.Domain.ReadModels.ProviderProgram
  alias KlassHero.Repo

  @impl true
  def get_by_id(program_id) when is_binary(program_id) do
    case Repo.get(ProviderProgramProjectionSchema, program_id) do
      nil -> {:error, :not_found}
      row -> {:ok, to_read_model(row)}
    end
  end

  @impl true
  def list_by_provider(provider_id) when is_binary(provider_id) do
    ProviderProgramProjectionSchema
    |> where([p], p.provider_id == ^provider_id)
    |> order_by([p], asc: p.name)
    |> Repo.all()
    |> Enum.map(&to_read_model/1)
  end

  defp to_read_model(%ProviderProgramProjectionSchema{} = row) do
    %ProviderProgram{
      program_id: row.program_id,
      provider_id: row.provider_id,
      name: row.name,
      status: row.status,
      inserted_at: row.inserted_at,
      updated_at: row.updated_at
    }
  end
end
