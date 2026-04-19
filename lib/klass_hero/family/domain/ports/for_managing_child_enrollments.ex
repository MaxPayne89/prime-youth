defmodule KlassHero.Family.Domain.Ports.ForManagingChildEnrollments do
  @moduledoc """
  Write-only port for managing enrollment data when deleting a child.

  Read operations have been moved to `ForQueryingChildEnrollments`.

  Family needs to cancel enrollments but cannot depend on
  the Enrollment context (which already depends on Family). This port
  is implemented by an ACL adapter that queries the enrollments table directly.
  """

  @doc "Cancels all active enrollments for a child. Returns count of cancelled rows."
  @callback cancel_active_for_child(child_id :: binary()) :: {:ok, non_neg_integer()}
end
