defmodule KlassHero.Enrollment.Domain.Ports.ForStoringBulkEnrollmentInvites do
  @moduledoc """
  Write-only port for bulk enrollment invite persistence operations.

  Defines the contract for invite write operations (CQRS command side).
  Read operations have been moved to `ForQueryingBulkEnrollmentInvites`.
  """

  alias KlassHero.Enrollment.Domain.Models.BulkEnrollmentInvite

  @doc """
  Inserts all invite records atomically in a single transaction.

  If any record fails validation, the entire batch is rolled back.

  Returns:
  - `{:ok, non_neg_integer()}` — count of created records
  - `{:error, term()}` — first changeset error from the batch
  """
  @callback create_batch([map()]) :: {:ok, non_neg_integer()} | {:error, term()}

  @doc """
  Inserts a single invite record and returns the persisted domain struct.

  Used by the manual single-invite flow where the caller needs the created
  invite's id (e.g. to acknowledge which row was created, to drive UI
  focus, or for tests). The batch path stays strictly count-returning to
  preserve its existing contract.

  Returns:
  - `{:ok, BulkEnrollmentInvite.t()}` on success
  - `{:error, Ecto.Changeset.t()}` if the row fails schema validation
  """
  @callback create_one(map()) ::
              {:ok, BulkEnrollmentInvite.t()}
              | {:error, Ecto.Changeset.t()}

  @doc """
  Assigns invite tokens to multiple invites in bulk.

  Accepts a list of `{invite_id, token}` tuples. Returns `{:ok, count}`
  with the number of rows updated.
  """
  @callback bulk_assign_tokens([{binary(), String.t()}]) :: {:ok, non_neg_integer()}

  @doc """
  Deletes an invite by its ID.

  Returns `:ok` on success, `{:error, :not_found}`, or `{:error, :delete_failed}`.
  """
  @callback delete(binary()) :: :ok | {:error, :not_found | :delete_failed}

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
