defmodule KlassHero.Identity.Application.UseCases.Verification.RejectVerificationDocument do
  @moduledoc """
  Use case for admin rejecting a verification document with a reason.

  Orchestrates the document rejection workflow:
  1. Validates that a rejection reason is provided
  2. Retrieves the document from the repository
  3. Applies the domain rejection logic (which validates the document is pending)
  4. Persists the updated document with rejection reason

  Only documents in :pending status can be rejected.
  """

  alias KlassHero.Identity.Domain.Models.VerificationDocument

  @doc """
  Rejects a pending verification document with a reason.

  ## Parameters

  - `document_id` - ID of the document to reject
  - `reviewer_id` - ID of the admin performing the review
  - `reason` - Explanation for why the document was rejected (required, non-empty)

  ## Returns

  - `{:ok, VerificationDocument.t()}` on success with updated status and rejection reason
  - `{:error, :reason_required}` if reason is empty or nil
  - `{:error, :not_found}` if document doesn't exist
  - `{:error, :document_not_pending}` if document is not in pending status
  """
  def execute(%{document_id: document_id, reviewer_id: reviewer_id, reason: reason}) do
    # Trigger: reason may be nil or empty string
    # Why: rejection requires explanation for provider to understand and fix
    # Outcome: early validation prevents rejecting without reason
    with :ok <- validate_reason(reason),
         {:ok, document} <- get_document(document_id),
         {:ok, rejected} <- VerificationDocument.reject(document, reviewer_id, reason) do
      repository().update(rejected)
    end
  end

  defp validate_reason(reason) when is_binary(reason) and byte_size(reason) > 0, do: :ok
  defp validate_reason(_), do: {:error, :reason_required}

  defp get_document(id), do: repository().get(id)

  defp repository do
    Application.get_env(:klass_hero, :identity)[:for_storing_verification_documents]
  end
end
