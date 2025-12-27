defmodule PrimeYouth.Attendance.Domain.Ports.ForResolvingChildNames do
  @moduledoc """
  Port for resolving child names from other bounded contexts.

  Provides anti-corruption layer between Attendance and Family contexts.
  Returns primitive strings, not domain objects from other contexts.

  ## Purpose

  This port enables Attendance context to obtain child names without directly
  depending on Family context's domain models, maintaining bounded context isolation.

  ## Error Types

  - `:child_not_found` - Child ID does not exist in Family context
  - `:database_connection_error` - Database connection failed
  - `:database_query_error` - Database query execution failed
  - `:database_unavailable` - Database unavailable or unexpected error

  ## Usage

      # In use cases
      case child_name_resolver().resolve_child_name(child_id) do
        {:ok, name} -> use_name(name)
        {:error, :child_not_found} -> use_fallback()
        {:error, _error} -> handle_database_error()
      end
  """

  @doc """
  Resolves a child's full name by their ID.

  ## Parameters

  - `child_id` - Binary UUID of the child

  ## Returns

  - `{:ok, child_name}` - Successfully resolved child's full name as a string
  - `{:error, resolution_error()}` - Failed to resolve child name

  ## Examples

      iex> resolve_child_name("550e8400-e29b-41d4-a716-446655440000")
      {:ok, "John Doe"}

      iex> resolve_child_name("invalid-id")
      {:error, :child_not_found}
  """
  @callback resolve_child_name(child_id :: String.t()) ::
              {:ok, child_name :: String.t()} | {:error, resolution_error()}

  @type resolution_error ::
          :child_not_found
          | :database_connection_error
          | :database_query_error
          | :database_unavailable
end
