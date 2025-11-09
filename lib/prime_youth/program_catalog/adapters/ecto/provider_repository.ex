defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.ProviderRepository do
  @moduledoc """
  Ecto adapter implementation of ProviderRepository port.

  Provides provider persistence operations using PostgreSQL via Ecto.
  """

  @behaviour PrimeYouth.ProgramCatalog.Domain.Ports.ProviderRepository

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Provider
  alias PrimeYouth.Repo

  @impl true
  def get_by_user_id(user_id) when is_binary(user_id) do
    case Repo.get_by(Provider, user_id: user_id) do
      nil -> {:error, :not_found}
      provider -> {:ok, provider}
    end
  end

  def get_by_user_id(_), do: {:error, :invalid_user_id}
end
