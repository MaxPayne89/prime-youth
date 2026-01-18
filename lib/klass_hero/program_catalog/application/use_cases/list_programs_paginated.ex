defmodule KlassHero.ProgramCatalog.Application.UseCases.ListProgramsPaginated do
  @moduledoc """
  Use case for listing programs with cursor-based pagination.

  This use case provides paginated access to the program catalog,
  returning a page of results with a cursor for retrieving subsequent pages.
  Supports optional category filtering at the database level.

  ## Example

      # Get first page with 20 programs
      {:ok, page_result} = ListProgramsPaginated.execute(20, nil)

      # Get next page using cursor from previous result
      {:ok, next_page} = ListProgramsPaginated.execute(20, page_result.next_cursor)

      # Get programs filtered by category
      {:ok, sports_programs} = ListProgramsPaginated.execute(20, nil, "sports")

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository
  alias KlassHero.ProgramCatalog.Domain.Services.ProgramCategories

  @doc """
  Lists programs with pagination.

  ## Parameters

    * `limit` - Maximum number of programs to return (1-100)
    * `cursor` - Optional cursor from previous page result (nil for first page)

  ## Returns

    * `{:ok, PageResult.t()}` - Page of programs with pagination metadata
    * `{:error, :invalid_cursor}` - Cursor is malformed or invalid

  """
  def execute(limit, cursor) do
    execute(limit, cursor, nil)
  end

  @doc """
  Lists programs with pagination and optional category filter.

  ## Parameters

    * `limit` - Maximum number of programs to return (1-100)
    * `cursor` - Optional cursor from previous page result (nil for first page)
    * `category` - Optional category to filter by (nil or "all" for all programs)

  ## Returns

    * `{:ok, PageResult.t()}` - Page of programs with pagination metadata
    * `{:error, :invalid_cursor}` - Cursor is malformed or invalid

  """
  def execute(limit, cursor, category) do
    validated_category = ProgramCategories.validate_filter(category)
    ProgramRepository.list_programs_paginated(limit, cursor, validated_category)
  end
end
