defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ProgramCatalogACL do
  @moduledoc """
  ACL adapter that resolves program titles for a provider.

  The Enrollment context needs program title->ID mappings for CSV import.

  ## Why direct DB query instead of ProgramCatalog facade?

  ProgramCatalog already depends on Enrollment (for capacity ACL).
  Adding Enrollment -> ProgramCatalog would create a dependency cycle.
  This adapter queries the `programs` table directly — acceptable in
  the adapter layer since it's infrastructure, not domain logic.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForResolvingProgramCatalog

  import Ecto.Query, only: [from: 2]

  alias KlassHero.Repo

  @impl true
  def list_program_titles_for_provider(provider_id) when is_binary(provider_id) do
    # Trigger: schemaless query on "programs" table
    # Why: ProgramCatalog depends on Enrollment (cycle), so we query directly.
    #      Ecto doesn't know field types without a schema, so we must cast
    #      provider_id to :binary_id for the UUID column comparison, and
    #      cast p.id in the select to get string UUIDs back (not raw bytes).
    # Outcome: returns %{"title" => "uuid"} map for the provider's programs
    query =
      from(p in "programs",
        where: p.provider_id == type(^provider_id, :binary_id),
        select: {p.title, type(p.id, :binary_id)}
      )

    query
    |> Repo.all()
    |> Map.new()
  end
end
