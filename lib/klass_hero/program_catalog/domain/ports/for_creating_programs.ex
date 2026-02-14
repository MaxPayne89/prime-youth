defmodule KlassHero.ProgramCatalog.Domain.Ports.ForCreatingPrograms do
  @moduledoc """
  Repository port for creating programs in the Program Catalog bounded context.

  Defines the contract for program creation. Implemented by adapters in
  the infrastructure layer.
  """

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @callback create(program :: Program.t()) ::
              {:ok, Program.t()} | {:error, Ecto.Changeset.t()}
end
