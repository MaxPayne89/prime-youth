defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.ChangeProgram do
  @moduledoc """
  Adapter for building program form changesets.

  Produces changesets for LiveView form tracking.
  """

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema

  def new_changeset(attrs \\ %{}) do
    %ProgramSchema{} |> ProgramSchema.create_changeset(attrs)
  end
end
