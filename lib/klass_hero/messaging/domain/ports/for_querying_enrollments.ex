defmodule KlassHero.Messaging.Domain.Ports.ForQueryingEnrollments do
  @moduledoc """
  Port for querying enrollment data in the Messaging bounded context.

  This behaviour defines the contract for querying enrollment data from
  the Enrollment bounded context. Used primarily for program broadcast
  messaging to find enrolled parents.
  """

  @doc """
  Gets all active enrolled parent user IDs for a program.

  Returns the user IDs (identity_ids from parents table) of all parents
  with active enrollments (pending or confirmed status) in the given program.

  ## Parameters
  - program_id: The program UUID to query

  ## Returns
  - List of unique user IDs (strings)
  """
  @callback get_enrolled_parent_user_ids(program_id :: String.t()) :: [String.t()]

  @doc """
  Checks if a parent has any active enrollment in a program.

  An active enrollment is one with status "pending" or "confirmed".

  ## Parameters
  - program_id: The program UUID
  - parent_user_id: The parent's user ID (identity_id)

  ## Returns
  - `true` if the parent has an active enrollment
  - `false` otherwise
  """
  @callback is_enrolled?(program_id :: String.t(), parent_user_id :: String.t()) :: boolean()
end
