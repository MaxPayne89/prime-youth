defmodule KlassHero.Identity.Domain.Ports.ForStoringVerificationDocuments do
  @moduledoc """
  Repository port for storing and retrieving verification documents in the Identity bounded context.

  This is a behaviour (interface) that defines the contract for verification document persistence.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  ## Expected Return Values

  - `create/1` - Returns `{:ok, VerificationDocument.t()}` or domain errors
  - `get/1` - Returns `{:ok, VerificationDocument.t()}` or `{:error, :not_found}`
  - `get_by_provider/1` - Returns `{:ok, [VerificationDocument.t()]}`
  - `update/1` - Returns `{:ok, VerificationDocument.t()}` or domain errors
  - `list_pending/0` - Returns `{:ok, [VerificationDocument.t()]}`
  - `list_by_status/1` - Returns `{:ok, [VerificationDocument.t()]}`

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Identity.Domain.Models.VerificationDocument

  @doc """
  Creates a new verification document in the repository.

  Accepts a VerificationDocument domain model.

  Returns:
  - `{:ok, VerificationDocument.t()}` - Document created successfully
  - `{:error, term()}` - Validation or persistence failure
  """
  @callback create(VerificationDocument.t()) ::
              {:ok, VerificationDocument.t()} | {:error, term()}

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
  Updates an existing verification document in the repository.

  Accepts a VerificationDocument domain model with updated fields.

  Returns:
  - `{:ok, VerificationDocument.t()}` - Document updated successfully
  - `{:error, term()}` - Validation or persistence failure
  """
  @callback update(VerificationDocument.t()) ::
              {:ok, VerificationDocument.t()} | {:error, term()}

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
end
