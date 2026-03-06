defmodule KlassHero.Family.Domain.Ports.ForManagingChildEnrollments do
  @moduledoc """
  Port for managing enrollment data when deleting a child.

  Family needs to query and cancel enrollments but cannot depend on
  the Enrollment context (which already depends on Family). This port
  is implemented by an ACL adapter that queries the enrollments table directly.
  """

  @type active_enrollment :: %{
          enrollment_id: String.t(),
          program_id: String.t(),
          program_title: String.t(),
          status: String.t()
        }

  @doc "Lists active enrollments for a child with program titles."
  @callback list_active_with_program_titles(child_id :: binary()) :: [active_enrollment()]

  @doc "Cancels all active enrollments for a child. Returns count of cancelled rows."
  @callback cancel_active_for_child(child_id :: binary()) :: {:ok, non_neg_integer()}
end
