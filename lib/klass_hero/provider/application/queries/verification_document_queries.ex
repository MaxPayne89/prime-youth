defmodule KlassHero.Provider.Application.Queries.VerificationDocumentQueries do
  @moduledoc """
  Query module for verification document reads.

  Centralises all read operations that depend on the verification document
  repository, keeping the facade free of direct repository references.
  """

  alias KlassHero.Provider.Domain.Models.VerificationDocument
  alias KlassHero.Provider.Domain.Ports.ForQueryingVerificationDocuments

  @verification_document_repository Application.compile_env!(:klass_hero, [
                                      :provider,
                                      :for_querying_verification_documents
                                    ])

  @doc """
  Get all verification documents for a provider.
  """
  @spec get_by_provider(String.t()) :: {:ok, [VerificationDocument.t()]}
  def get_by_provider(provider_id) do
    @verification_document_repository.get_by_provider(provider_id)
  end

  @doc """
  List all pending verification documents (admin).
  """
  @spec list_pending() :: {:ok, [VerificationDocument.t()]}
  def list_pending do
    @verification_document_repository.list_pending()
  end

  @doc """
  List verification documents with provider info for admin review.

  Accepts an optional status filter atom:
  - `nil` - All documents (newest first)
  - `:pending` - Pending documents (oldest first, FIFO)
  - `:approved` - Approved documents (newest first)
  - `:rejected` - Rejected documents (newest first)
  """
  @spec list_for_admin_review(VerificationDocument.status() | nil) ::
          {:ok, [ForQueryingVerificationDocuments.admin_review_result()]}
  def list_for_admin_review(status \\ nil) do
    @verification_document_repository.list_for_admin_review(status)
  end

  @doc """
  Get a single verification document with provider info for admin review.
  """
  @spec get_for_admin_review(String.t()) ::
          {:ok, ForQueryingVerificationDocuments.admin_review_result()} | {:error, :not_found}
  def get_for_admin_review(document_id) do
    @verification_document_repository.get_for_admin_review(document_id)
  end
end
