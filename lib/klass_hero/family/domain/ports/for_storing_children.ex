defmodule KlassHero.Family.Domain.Ports.ForStoringChildren do
  @moduledoc """
  Write-only port for child persistence operations in the Family bounded context.

  Read operations have been moved to `ForQueryingChildren`.

  ## Expected Return Values

  - `create/1` - Returns `{:ok, Child.t()}` or `{:error, changeset}`
  - `update/2` - Returns `{:ok, Child.t()}` or errors
  - `delete/1` - Returns `:ok` or errors

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Family.Domain.Models.Child

  @doc """
  Creates a new child record.

  Returns:
  - `{:ok, Child.t()}` - Child created successfully
  - `{:error, changeset}` - Validation failed
  """
  @callback create(map()) :: {:ok, Child.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates an existing child record.

  Returns:
  - `{:ok, Child.t()}` - Child updated successfully
  - `{:error, :not_found}` - Child ID doesn't exist
  - `{:error, changeset}` - Validation failed
  """
  @callback update(binary(), map()) ::
              {:ok, Child.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}

  @doc """
  Deletes a child record.

  Returns:
  - `:ok` - Child deleted successfully
  - `{:error, :not_found}` - Child ID doesn't exist
  - `{:error, changeset}` - Delete failed (e.g. FK constraint)
  """
  @callback delete(binary()) :: :ok | {:error, :not_found} | {:error, Ecto.Changeset.t()}

  @doc """
  Creates a new child and links it to a guardian atomically.

  Both the child record and the guardian link are created in a single
  transaction. If either fails, both are rolled back.

  Returns:
  - `{:ok, Child.t()}` - Child created and linked successfully
  - `{:error, changeset}` - Validation failed
  """
  @callback create_with_guardian(map(), binary()) ::
              {:ok, Child.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Anonymizes a child record for GDPR account deletion.

  Receives the anonymized attribute values from the domain model and applies
  them mechanically. The adapter does not decide what "anonymized" means.

  Returns:
  - `{:ok, Child.t()}` - Child anonymized successfully
  - `{:error, :not_found}` - Child ID doesn't exist
  - `{:error, changeset}` - Update failed
  """
  @callback anonymize(binary(), map()) ::
              {:ok, Child.t()} | {:error, :not_found | Ecto.Changeset.t()}
end
