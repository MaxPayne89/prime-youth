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
  Retrieves a single invite by its invite token.

  Returns the invite domain struct or nil if not found.
  """
  @callback get_by_token(binary() | nil) :: struct() | nil

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
  Returns all invites for a given program, ordered alphabetically
  by child last name then first name.
  """
  @callback list_by_program(binary()) :: [struct()]

  @doc """
  Returns the count of invites for a given program.
  """
  @callback count_by_program(binary()) :: non_neg_integer()

  @doc """
  Deletes an invite by its ID.

  Returns `:ok` on success or `{:error, :not_found}` if the invite does not exist.
  """
  @callback delete(binary()) :: :ok | {:error, :not_found}

  @doc """
  Transitions an invite's status using the schema's state machine.

  Validates that the transition is legal per `transition_changeset/2`.
  Returns `{:ok, updated_invite}` or `{:error, changeset}`.
  """
  @callback transition_status(struct(), map()) :: {:ok, struct()} | {:error, term()}

  @doc """
  Resets a resendable invite back to pending status, clearing its token and metadata.

  Only invites in `pending`, `invite_sent`, or `failed` status can be reset.
  Returns `{:error, :not_resendable}` for terminal statuses like `enrolled`.
  Returns `{:error, :not_found}` if the invite does not exist in the database.
  """
  @callback reset_for_resend(struct()) :: {:ok, struct()} | {:error, :not_found | :not_resendable}
end
