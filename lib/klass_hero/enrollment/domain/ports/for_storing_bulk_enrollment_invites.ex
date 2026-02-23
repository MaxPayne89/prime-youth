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

  @doc """
  Retrieves a single invite by its ID.

  Returns the invite struct or nil if not found.
  """
  @callback get_by_id(binary()) :: struct() | nil

  @doc """
  Returns pending invites that have not yet been assigned an invite token.

  Filters by program IDs, status "pending", and nil invite_token.
  Returns an empty list when given an empty list of program IDs.
  """
  @callback list_pending_without_token([binary()]) :: [struct()]

  @doc """
  Assigns invite tokens to multiple invites in bulk.

  Accepts a list of `{invite_id, token}` tuples. Returns `{:ok, count}`
  with the number of rows updated.
  """
  @callback bulk_assign_tokens([{binary(), String.t()}]) :: {:ok, non_neg_integer()}

  @doc """
  Transitions an invite's status using the schema's state machine.

  Validates that the transition is legal per `transition_changeset/2`.
  Returns `{:ok, updated_invite}` or `{:error, changeset}`.
  """
  @callback transition_status(struct(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
end
