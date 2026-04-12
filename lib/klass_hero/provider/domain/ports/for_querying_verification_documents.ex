defmodule KlassHero.Provider.Domain.Ports.ForQueryingVerificationDocuments do
  @moduledoc """
  Read-only port for querying verification documents in the Provider bounded context.

  Separated from `ForStoringVerificationDocuments` (write-only) to support CQRS at
  the port level. Read operations never mutate state.
  """

  alias KlassHero.Provider.Domain.Models.VerificationDocument

  @typedoc "Result map returned by admin review queries, pairing a document with its provider's business name."
  @type admin_review_result :: %{
          document: VerificationDocument.t(),
          provider_business_name: String.t()
        }

  @doc """
  Retrieves a verification document by its ID.

  Returns:
  - `{:ok, VerificationDocument.t()}` - Document found with matching ID
  - `{:error, :not_found}` - No document exists with this ID
  """
  @callback get(id :: String.t()) ::
              {:ok, VerificationDocument.t()} | {:error, :not_found}

  @doc """
  Retrieves all verification documents for a specific provider.

  Returns:
  - `{:ok, [VerificationDocument.t()]}` - List of documents (may be empty)
  """
  @callback get_by_provider(provider_id :: String.t()) ::
              {:ok, [VerificationDocument.t()]}

  @doc """
  Lists all verification documents with pending status.

  Returns:
  - `{:ok, [VerificationDocument.t()]}` - List of pending documents (may be empty)
  """
  @callback list_pending() ::
              {:ok, [VerificationDocument.t()]}

  @doc """
  Lists all verification documents with the specified status.

  Returns:
  - `{:ok, [VerificationDocument.t()]}` - List of documents with matching status (may be empty)
  """
  @callback list_by_status(VerificationDocument.status()) ::
              {:ok, [VerificationDocument.t()]}

  @doc """
  Lists verification documents with provider business names for admin review.

  Accepts an optional status filter. When nil, returns all documents.
  Pending documents are ordered oldest-first (FIFO), others newest-first.

  Returns:
  - `{:ok, [admin_review_result()]}`
  """
  @callback list_for_admin_review(VerificationDocument.status() | nil) ::
              {:ok, [admin_review_result()]}

  @doc """
  Retrieves a single verification document with provider business name for admin review.

  Returns:
  - `{:ok, admin_review_result()}`
  - `{:error, :not_found}` if no document exists with this ID
  """
  @callback get_for_admin_review(id :: String.t()) ::
              {:ok, admin_review_result()} | {:error, :not_found}
end
