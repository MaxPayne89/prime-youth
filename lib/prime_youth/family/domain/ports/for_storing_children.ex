defmodule PrimeYouth.Family.Domain.Ports.ForStoringChildren do
  @moduledoc """
  Port for child persistence operations.

  Defines the contract for storing and retrieving children without exposing
  infrastructure details. Implementations will be provided by repository adapters.

  ## Error Types

  - `:database_connection_error` - Cannot connect to database
  - `:database_query_error` - Query execution failed (constraint violations, invalid data)
  - `:database_unavailable` - Database temporarily unavailable
  - `:not_found` - Child ID doesn't exist (domain error, not infrastructure)

  ## Callbacks

  - `get_by_id/1` - Retrieve a child by their unique identifier
  - `create/1` - Create a new child record
  - `list_by_parent/1` - List all children for a given parent
  """

  alias PrimeYouth.Family.Domain.Models.Child

  @type child_id :: String.t()
  @type parent_id :: String.t()

  @type database_error ::
          :database_connection_error
          | :database_query_error
          | :database_unavailable

  @type persistence_error :: database_error | :not_found

  @doc """
  Retrieves a child by their unique identifier.

  Primary method for attendance lookups to resolve child names.

  ## Returns

  - `{:ok, Child.t()}` - Child found successfully
  - `{:error, :not_found}` - Child ID doesn't exist
  - `{:error, database_error}` - Database operation failed
  """
  @callback get_by_id(child_id) ::
              {:ok, Child.t()} | {:error, persistence_error}

  @doc """
  Creates a new child record.

  Accepts a map of validated attributes (from use case layer) and returns
  the created child as a domain entity.

  ## Returns

  - `{:ok, Child.t()}` - Child created successfully
  - `{:error, database_error}` - Database operation failed
  """
  @callback create(map()) ::
              {:ok, Child.t()} | {:error, database_error}

  @doc """
  Lists all children for a given parent.

  Used for family dashboard and parent-specific child management.

  ## Returns

  - `{:ok, [Child.t()]}` - List of children (may be empty)
  - `{:error, database_error}` - Database operation failed
  """
  @callback list_by_parent(parent_id) ::
              {:ok, [Child.t()]} | {:error, database_error}
end
