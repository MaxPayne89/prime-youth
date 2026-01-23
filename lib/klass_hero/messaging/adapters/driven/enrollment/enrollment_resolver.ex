defmodule KlassHero.Messaging.Adapters.Driven.Enrollment.EnrollmentResolver do
  @moduledoc """
  Adapter for querying enrollment data from the Enrollment bounded context.

  This adapter queries the enrollment context to find enrolled parents
  for program broadcast functionality.
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForQueryingEnrollments

  import Ecto.Query

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ParentProfileSchema
  alias KlassHero.Repo

  @active_statuses ["pending", "confirmed"]

  @impl true
  @spec get_enrolled_parent_user_ids(String.t()) :: [String.t()]
  def get_enrolled_parent_user_ids(program_id) do
    from(e in EnrollmentSchema,
      join: p in ParentProfileSchema,
      on: e.parent_id == p.id,
      where: e.program_id == ^program_id and e.status in @active_statuses,
      select: p.identity_id,
      distinct: true
    )
    |> Repo.all()
  end

  @impl true
  @spec is_enrolled?(String.t(), String.t()) :: boolean()
  def is_enrolled?(program_id, parent_user_id) do
    from(e in EnrollmentSchema,
      join: p in ParentProfileSchema,
      on: e.parent_id == p.id,
      where:
        e.program_id == ^program_id and
          p.identity_id == ^parent_user_id and
          e.status in @active_statuses
    )
    |> Repo.exists?()
  end
end
