defmodule KlassHero.Family.Domain.Ports.ForStoringChildren do
  @moduledoc """
  Port for child persistence operations in the Family bounded context.

  Defines the contract for storing and retrieving children without exposing
  infrastructure details. Implementations will be provided by repository adapters.

  ## Expected Return Values

  - `get_by_id/1` - Returns `{:ok, Child.t()}` or `{:error, :not_found}`
  - `create/1` - Returns `{:ok, Child.t()}` or `{:error, changeset}`
  - `list_by_guardian/1` - Returns list of children for a guardian

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Family.Domain.Models.Child

  @doc """
  Retrieves a child by their unique identifier.

  Returns:
  - `{:ok, Child.t()}` - Child found successfully
  - `{:error, :not_found}` - Child ID doesn't exist
  """
  @callback get_by_id(binary()) :: {:ok, Child.t()} | {:error, :not_found}

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
  Lists all children for a given guardian, queried through the children_guardians join table.

  Returns list of children (may be empty).
  """
  @callback list_by_guardian(binary()) :: [Child.t()]

  @doc """
  Retrieves multiple children by their IDs.

  Returns list of children found (may be shorter than input if some IDs don't exist).
  """
  @callback list_by_ids([binary()]) :: [Child.t()]

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
