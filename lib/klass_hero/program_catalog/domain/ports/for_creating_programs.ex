defmodule KlassHero.ProgramCatalog.Domain.Ports.ForCreatingPrograms do
  @moduledoc """
  Repository port for creating programs in the Program Catalog bounded context.

  Defines the contract for program creation. Implemented by adapters in
  the infrastructure layer.
  """

  @callback create(attrs :: map()) ::
              {:ok, term()} | {:error, term()}
end
