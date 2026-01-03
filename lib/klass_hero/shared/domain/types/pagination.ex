defmodule KlassHero.Shared.Domain.Types.Pagination do
  @moduledoc """
  Shared pagination types for cursor-based pagination across bounded contexts.

  This module provides pure domain types for implementing seek pagination (cursor-based)
  without any infrastructure dependencies.
  """

  defmodule PageParams do
    @moduledoc """
    Input parameters for paginated queries.

    Fields:
    - `limit`: Number of items per page (default: 20, range: 1-100)
    - `cursor`: Base64-encoded cursor string for pagination, nil for first page
    """

    @default_limit 20
    @min_limit 1
    @max_limit 100

    defstruct limit: @default_limit, cursor: nil

    def new(attrs \\ []) do
      %__MODULE__{
        limit: Keyword.get(attrs, :limit, @default_limit),
        cursor: Keyword.get(attrs, :cursor)
      }
      |> validate()
    end

    def validate(%__MODULE__{limit: limit} = params) when is_integer(limit) do
      cond do
        limit < @min_limit ->
          {:ok, %{params | limit: @min_limit}}

        limit > @max_limit ->
          {:ok, %{params | limit: @max_limit}}

        true ->
          {:ok, params}
      end
    end

    def validate(%__MODULE__{limit: limit}) when not is_integer(limit) do
      {:error, :invalid_limit}
    end
  end

  defmodule PageResult do
    @moduledoc """
    Output structure for paginated results.

    Fields:
    - `items`: List of domain entities for the current page
    - `next_cursor`: Base64-encoded cursor for next page, nil if no more pages
    - `has_more`: Boolean indicating if more pages are available
    - `metadata`: Map with additional information (e.g., returned_count)
    """

    defstruct items: [], next_cursor: nil, has_more: false, metadata: %{}

    def new(items, next_cursor, has_more) when is_list(items) and is_boolean(has_more) do
      %__MODULE__{
        items: items,
        next_cursor: next_cursor,
        has_more: has_more,
        metadata: %{
          returned_count: length(items)
        }
      }
    end
  end
end
