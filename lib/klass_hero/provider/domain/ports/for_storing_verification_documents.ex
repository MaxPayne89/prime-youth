defmodule KlassHero.Provider.Domain.Ports.ForStoringVerificationDocuments do
  @moduledoc """
  Write-only port for storing verification documents in the Provider bounded context.

  Read operations have been moved to `ForQueryingVerificationDocuments`.

  ## Expected Return Values

  - `create/1` - Returns `{:ok, VerificationDocument.t()}` or domain errors
  - `update/1` - Returns `{:ok, VerificationDocument.t()}` or domain errors

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Provider.Domain.Models.VerificationDocument

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
  Updates an existing verification document in the repository.

  Accepts a VerificationDocument domain model with updated fields.

  Returns:
  - `{:ok, VerificationDocument.t()}` - Document updated successfully
  - `{:error, term()}` - Validation or persistence failure
  """
  @callback update(VerificationDocument.t()) ::
              {:ok, VerificationDocument.t()} | {:error, term()}
end
