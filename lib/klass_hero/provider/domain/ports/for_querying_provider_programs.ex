defmodule KlassHero.Provider.Domain.Ports.ForQueryingProviderPrograms do
  @moduledoc """
  Read port for provider-owned program data projected from Program Catalog events.
  """

  alias KlassHero.Provider.Domain.ReadModels.ProviderProgram

  @callback get_by_id(program_id :: Ecto.UUID.t()) ::
              {:ok, ProviderProgram.t()} | {:error, :not_found}

  @callback list_by_provider(provider_id :: Ecto.UUID.t()) :: [ProviderProgram.t()]
end
