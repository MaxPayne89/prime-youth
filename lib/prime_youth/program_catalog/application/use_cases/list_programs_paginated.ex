defmodule PrimeYouth.ProgramCatalog.Application.UseCases.ListProgramsPaginated do
  @moduledoc """
  Use case for listing programs with cursor-based pagination.

  This use case provides paginated access to the program catalog,
  returning a page of results with a cursor for retrieving subsequent pages.

  ## Example

      # Get first page with 20 programs
      {:ok, page_result} = ListProgramsPaginated.execute(20, nil)

      # Get next page using cursor from previous result
      {:ok, next_page} = ListProgramsPaginated.execute(20, page_result.next_cursor)

  """

  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository
  alias PrimeYouth.Shared.Domain.Types.Pagination.PageResult

  @doc """
  Lists programs with pagination.

  ## Parameters

    * `limit` - Maximum number of programs to return (1-100)
    * `cursor` - Optional cursor from previous page result (nil for first page)

  ## Returns

    * `{:ok, PageResult.t()}` - Page of programs with pagination metadata
    * `{:error, :invalid_cursor}` - Cursor is malformed or invalid
    * `{:error, :database_connection_error}` - Database connection failed
    * `{:error, :database_query_error}` - Query execution failed
    * `{:error, :database_unavailable}` - Unexpected database error

  """
  @spec execute(pos_integer(), String.t() | nil) ::
          {:ok, PageResult.t()} | {:error, atom()}
  def execute(limit, cursor) do
    ProgramRepository.list_programs_paginated(limit, cursor)
  end
end
