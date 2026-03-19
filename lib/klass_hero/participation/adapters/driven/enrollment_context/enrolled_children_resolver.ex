defmodule KlassHero.Participation.Adapters.Driven.EnrollmentContext.EnrolledChildrenResolver do
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

  @impl true
  def list_enrolled_child_ids(program_id) when is_binary(program_id) do
    program_id
    |> Enrollment.list_program_enrollments()
    |> Enum.map(& &1.child_id)
    |> Enum.uniq()
  end
end
