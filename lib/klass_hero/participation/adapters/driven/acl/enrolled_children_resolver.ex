defmodule KlassHero.Participation.Adapters.Driven.ACL.EnrolledChildrenResolver do
  @moduledoc """
  ACL adapter that resolves enrolled child IDs from the Enrollment context.

  ## Anti-Corruption Layer

  This adapter serves as an ACL between the Participation and Enrollment
  bounded contexts. It:

  1. Queries Enrollment for active enrollments via its public API
  2. Extracts only child_id values — no other enrollment data leaks

  ## Architecture

  ```
  SeedSessionRoster → ForResolvingEnrolledChildren Port → [THIS ADAPTER] → Enrollment Public API
       (use case)        (behaviour contract)              (data filter)     (owns enrollments)
  ```
  """

  @behaviour KlassHero.Participation.Domain.Ports.ForResolvingEnrolledChildren

  alias KlassHero.Enrollment

  # Trigger: uses enriched roster endpoint rather than a lean child-IDs-only query
  # Why: deliberate trade-off — slight over-fetching (name/parent resolution) avoids
  #      adding new functions to the Enrollment context. Acceptable for class-sized lists.
  # Outcome: returns only child_id values; enrichment data is discarded at the ACL boundary
  @impl true
  def list_enrolled_child_ids(program_id) when is_binary(program_id) do
    program_id
    |> Enrollment.list_program_enrollments()
    |> Enum.map(& &1.child_id)
    # Defensive: DB unique partial index prevents duplicate active enrollments per child/program,
    # but dedup here guards against any future loosening of that constraint
    |> Enum.uniq()
  end
end
