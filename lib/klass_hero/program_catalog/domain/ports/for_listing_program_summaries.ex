defmodule KlassHero.ProgramCatalog.Domain.Ports.ForListingProgramSummaries do
  @moduledoc """
  Read port for querying the program_listings denormalized read model.

  This port defines the contract for read-side queries against the CQRS
  read table. The projection GenServer handles writes; this port handles
  reads only.

  Implemented by the ProgramListingsRepository adapter.
  """

  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHero.Shared.Domain.Types.Pagination.PageResult

  @doc """
  Lists program listings with cursor-based pagination and optional category filter.

  Uses seek pagination (cursor-based) for efficient pagination of large result sets.
  Listings are ordered by creation time (newest first) using (inserted_at DESC, id DESC).

  Parameters:
  - `limit` - Number of items per page (1-100)
  - `cursor` - Base64-encoded cursor for pagination, nil for first page
  - `category` - Category to filter by, or nil for all categories

  Returns:
  - `{:ok, %PageResult{}}` - Page of program listings with pagination metadata
  - `{:error, :invalid_cursor}` - Cursor decoding/validation failure
  """
  @callback list_paginated(
              limit :: pos_integer(),
              cursor :: binary() | nil,
              category :: String.t() | nil
            ) ::
              {:ok, %PageResult{}} | {:error, :invalid_cursor}

  @doc """
  Lists all program listings for a specific provider.

  Returns listings in ascending order by title for consistent display.
  Returns an empty list if the provider has no programs.
  """
  @callback list_for_provider(provider_id :: String.t()) :: [ProgramListing.t()]

  @doc """
  Retrieves a single program listing by its unique ID (UUID).

  Returns:
  - `{:ok, ProgramListing.t()}` - Listing found with matching ID
  - `{:error, :not_found}` - No listing exists with the given ID
  """
  @callback get_by_id(id :: binary()) :: {:ok, ProgramListing.t()} | {:error, :not_found}

  @doc """
  Lists all program listings ordered by title.

  Returns all non-archived program listings in ascending title order.
  Returns an empty list if no listings exist.
  """
  @callback list_all() :: [ProgramListing.t()]
end
