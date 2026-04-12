defmodule KlassHero.Family.Domain.Ports.ForQueryingChildEnrollments do
  @moduledoc """
  Read-only port for querying child enrollment data in the Family bounded context.

  Separated from `ForManagingChildEnrollments` (write-only) to support CQRS at
  the port level. Read operations never mutate state.

  Family needs to query enrollments but cannot depend on the Enrollment context
  (which already depends on Family). This port is implemented by an ACL adapter
  that queries the enrollments table directly.
  """

  @type active_enrollment :: %{
          enrollment_id: String.t(),
          program_id: String.t(),
          program_title: String.t(),
          # "pending" | "confirmed" — only active statuses returned
          status: String.t()
        }

  @doc "Lists active enrollments for a child with program titles."
  @callback list_active_with_program_titles(child_id :: binary()) :: [active_enrollment()]
end
