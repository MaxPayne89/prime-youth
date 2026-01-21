defmodule KlassHero.Shared.Domain.Types.Pagination do
  @moduledoc """
  Shared pagination types for cursor-based pagination across bounded contexts.

  This module provides pure domain types for implementing seek pagination (cursor-based)
  without any infrastructure dependencies.
  """

  defmodule PageParams do
    @moduledoc """
    Input parameters for paginated queries.

    ## Fields

    - `limit`: Number of items per page (default: 20, range: 1-100)
    - `cursor`: Base64-encoded cursor string for pagination, nil for first page

    ## Validation Behavior

    The `validate/1` function uses **clamping** rather than rejection for out-of-range
    limit values. This provides a better user experience by automatically adjusting
    invalid limits to the nearest valid boundary:

    - Limits below 1 are clamped to 1
    - Limits above 100 are clamped to 100
    - Non-integer limits return `{:error, :invalid_limit}`

    This approach ensures API consumers always receive valid paginated results
    rather than errors for reasonable limit values.
    """

    @default_limit 20
    @min_limit 1
    @max_limit 100

    defstruct limit: @default_limit, cursor: nil

    @doc """
    Creates new PageParams with optional attributes.

    ## Examples

        iex> PageParams.new()
        {:ok, %PageParams{limit: 20, cursor: nil}}

        iex> PageParams.new(limit: 50, cursor: "abc123")
        {:ok, %PageParams{limit: 50, cursor: "abc123"}}

        iex> PageParams.new(limit: 200)
        {:ok, %PageParams{limit: 100, cursor: nil}}  # Clamped to max
    """
    def new(attrs \\ []) do
      %__MODULE__{
        limit: Keyword.get(attrs, :limit, @default_limit),
        cursor: Keyword.get(attrs, :cursor)
      }
      |> validate()
    end

    @doc """
    Validates and clamps PageParams to valid boundaries.

    Out-of-range integer limits are clamped to valid boundaries (1-100).
    Non-integer limits return an error.

    ## Examples

        iex> PageParams.validate(%PageParams{limit: 50})
        {:ok, %PageParams{limit: 50, cursor: nil}}

        iex> PageParams.validate(%PageParams{limit: 0})
        {:ok, %PageParams{limit: 1, cursor: nil}}  # Clamped to min

        iex> PageParams.validate(%PageParams{limit: 500})
        {:ok, %PageParams{limit: 100, cursor: nil}}  # Clamped to max

        iex> PageParams.validate(%PageParams{limit: "invalid"})
        {:error, :invalid_limit}
    """
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
