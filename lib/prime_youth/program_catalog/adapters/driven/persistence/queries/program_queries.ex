defmodule PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Queries.ProgramQueries do
  @moduledoc """
  Composable Ecto query functions for program listing and filtering.

  This module provides building blocks for constructing program queries
  with support for pagination, ordering, and filtering (Pattern 2).
  """

  import Ecto.Query

  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema

  def base_query do
    from(p in ProgramSchema)
  end

  def order_by_creation(query, direction \\ :desc)

  def order_by_creation(query, :desc) do
    from(p in query, order_by: [desc: p.inserted_at, desc: p.id])
  end

  def order_by_creation(query, :asc) do
    from(p in query, order_by: [asc: p.inserted_at, asc: p.id])
  end

  def paginate_after_cursor(query, cursor_data, direction \\ :desc)

  def paginate_after_cursor(query, {cursor_ts, cursor_id}, :desc) do
    from(p in query,
      where:
        p.inserted_at < ^cursor_ts or
          (p.inserted_at == ^cursor_ts and p.id < ^cursor_id)
    )
  end

  def paginate_after_cursor(query, {cursor_ts, cursor_id}, :asc) do
    from(p in query,
      where:
        p.inserted_at > ^cursor_ts or
          (p.inserted_at == ^cursor_ts and p.id > ^cursor_id)
    )
  end

  def limit_results(query, limit) when is_integer(limit) and limit > 0 do
    from(p in query, limit: ^limit)
  end
end
