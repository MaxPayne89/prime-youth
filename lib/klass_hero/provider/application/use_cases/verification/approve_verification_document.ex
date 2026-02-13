defmodule KlassHero.Provider.Application.UseCases.Verification.ApproveVerificationDocument do
  @moduledoc """
  Use case for admin approving a verification document.

  Orchestrates the document approval workflow:
  1. Retrieves the document from the repository
  2. Applies the domain approval logic (which validates the document is pending)
  3. Persists the updated document

  Only documents in :pending status can be approved.
  """

  alias KlassHero.Provider.Domain.Models.VerificationDocument

  @repository Application.compile_env!(:klass_hero, [
                :provider,
                :for_storing_verification_documents
              ])

  @doc """
  Approves a pending verification document.

  ## Parameters

  - `document_id` - ID of the document to approve
  - `reviewer_id` - ID of the admin performing the review

  ## Returns

  - `{:ok, VerificationDocument.t()}` on success with updated status
  - `{:error, :not_found}` if document doesn't exist
  - `{:error, :document_not_pending}` if document is not in pending status
  """
  def execute(%{document_id: document_id, reviewer_id: reviewer_id}) do
    with {:ok, document} <- @repository.get(document_id),
         {:ok, approved} <- VerificationDocument.approve(document, reviewer_id) do
      @repository.update(approved)
    end
  end
end
