defmodule KlassHero.Enrollment.Domain.Ports.ForStoringBulkEnrollmentInvites do
  @moduledoc """
  Write-only port for bulk enrollment invite persistence operations.

  Defines the contract for invite write operations (CQRS command side).
  Read operations have been moved to `ForQueryingBulkEnrollmentInvites`.
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
