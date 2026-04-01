defmodule KlassHero.Messaging.Domain.Ports.ForResolvingProgramStaff do
  @moduledoc """
  Port for querying the program staff participants projection.
  Kept in sync by integration events from the Provider context.
  """

  @doc """
  Returns the user IDs of all active staff assigned to the given program.

  ## Parameters
  - program_id: The program UUID

  ## Returns
  - List of staff user ID strings
  """
  @callback get_active_staff_user_ids(program_id :: String.t()) :: [String.t()]

  @doc """
  Inserts or reactivates a staff participant record for the given program.

  Uses upsert semantics: if a record for (program_id, staff_user_id) already
  exists it is updated with active: true; otherwise a new record is created.

  ## Parameters
  - attrs: Map with keys :provider_id, :program_id, :staff_user_id

  ## Returns
  - :ok on success
  - {:error, term()} on failure
  """
  @callback upsert_active(attrs :: map()) :: :ok | {:error, term()}

  @doc """
  Marks the staff participant record for (program_id, staff_user_id) as inactive.

  Is a no-op if no such record exists.

  ## Parameters
  - program_id: The program UUID
  - staff_user_id: The staff member's user UUID

  ## Returns
  - :ok
  """
  @callback deactivate(program_id :: String.t(), staff_user_id :: String.t()) :: :ok
end
