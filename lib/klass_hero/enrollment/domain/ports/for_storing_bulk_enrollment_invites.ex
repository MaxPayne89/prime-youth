defmodule KlassHero.Enrollment.Domain.Ports.ForStoringBulkEnrollmentInvites do
  @moduledoc """
  Port for bulk enrollment invite persistence operations.

  Defines the contract for batch-creating and querying invite records
  without exposing infrastructure details.
  """

  @doc """
  Inserts all invite records atomically in a single transaction.

  If any record fails validation, the entire batch is rolled back.

  Returns:
  - `{:ok, non_neg_integer()}` — count of created records
  - `{:error, term()}` — first changeset error from the batch
  """
  @callback create_batch([map()]) :: {:ok, non_neg_integer()} | {:error, term()}

  @doc """
  Returns existing invite keys for the given program IDs.

  Used for duplicate detection before batch insert. Returns a MapSet
  of `{program_id, guardian_email, child_first_name, child_last_name}` tuples.
  """
  @callback list_existing_keys_for_programs([binary()]) :: MapSet.t()
end
