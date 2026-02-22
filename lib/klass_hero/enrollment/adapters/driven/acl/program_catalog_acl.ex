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
    # Trigger: provider_id may not be a valid UUID
    # Why: type(^provider_id, :binary_id) raises Ecto.Query.CastError on invalid format
    # Outcome: invalid UUID returns empty map; build_context handles the empty-map case
    case Ecto.UUID.cast(provider_id) do
      {:ok, _} ->
        from(p in "programs",
          where: p.provider_id == type(^provider_id, :binary_id),
          select: {p.title, type(p.id, :binary_id)}
        )
        |> Repo.all()
        |> Map.new()

      :error ->
        %{}
    end
  end
end
