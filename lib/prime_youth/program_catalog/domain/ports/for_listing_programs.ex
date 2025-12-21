defmodule PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms do
  @moduledoc """
  Repository port for listing programs in the Program Catalog bounded context.

  This is a behaviour (interface) that defines the contract for program persistence.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  This port follows the Ports & Adapters architecture pattern, keeping the domain
  layer independent of infrastructure concerns.
  """

  alias PrimeYouth.ProgramCatalog.Domain.Models.Program
  alias PrimeYouth.Shared.Domain.Types.Pagination.PageResult

  @typedoc """
  Specific error types for program listing operations.

  - `:database_connection_error` - Network/connection issues (potentially retryable)
  - `:database_query_error` - SQL syntax, constraints, schema issues (non-retryable)
  - `:database_unavailable` - Generic/unexpected errors (fallback)
  - `:invalid_cursor` - Cursor decoding/validation failure (non-retryable)
  """
  @type list_error ::
          :database_connection_error
          | :database_query_error
          | :database_unavailable
          | :invalid_cursor

  @doc """
  Lists all valid programs from the repository.

  Only programs with all required fields populated are returned.
  Programs are returned in ascending order by title.

  Returns:
  - `{:ok, [Program.t()]}` - List of valid programs (may be empty)
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, programs} = list_all_programs()
      {:error, :database_connection_error} = list_all_programs()
      {:error, :database_query_error} = list_all_programs()
  """
  @callback list_all_programs() :: {:ok, [Program.t()]} | {:error, list_error()}

  @doc """
  Retrieves a single program by its unique ID (UUID).

  Returns the program with all required fields populated if found.

  Returns:
  - `{:ok, Program.t()}` - Program found with matching ID
  - `{:error, :not_found}` - No program exists with the given ID
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      {:ok, program} = get_by_id("550e8400-e29b-41d4-a716-446655440001")
      {:error, :not_found} = get_by_id("550e8400-e29b-41d4-a716-446655440099")
      {:error, :database_connection_error} = get_by_id("invalid-uuid")
  """
  @callback get_by_id(String.t()) :: {:ok, Program.t()} | {:error, :not_found | list_error()}

  @doc """
  Lists programs with cursor-based pagination.

  Uses seek pagination with a cursor-based approach for efficient pagination
  of large result sets. The cursor encodes the position in the result set
  and should be treated as an opaque string.

  Programs are returned in descending order by creation time (newest first),
  with deterministic ordering using (inserted_at DESC, id DESC).

  Parameters:
  - `limit` - Number of items per page (1-100, silently constrained if out of range)
  - `cursor` - Base64-encoded cursor for pagination, nil for first page

  Returns:
  - `{:ok, PageResult.t()}` - Page of programs with pagination metadata
  - `{:error, :invalid_cursor}` - Cursor decoding/validation failure
  - `{:error, :database_connection_error}` - Connection/network failure
  - `{:error, :database_query_error}` - SQL error or constraint violation
  - `{:error, :database_unavailable}` - Unexpected error

  ## Examples

      # First page
      {:ok, page} = list_programs_paginated(20, nil)
      page.items          # List of programs
      page.next_cursor    # Cursor for next page (nil if last page)
      page.has_more       # Boolean indicating more pages available

      # Subsequent page
      {:ok, page2} = list_programs_paginated(20, page.next_cursor)
  """
  @callback list_programs_paginated(limit :: pos_integer(), cursor :: String.t() | nil) ::
              {:ok, PageResult.t()} | {:error, list_error()}
end
