defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Queries.AttendanceQueries do
  @moduledoc """
  Composable Ecto query functions for attendance record listing and filtering.

  This module provides building blocks for constructing attendance queries
  with support for filtering, joining, ordering, and limiting (Pattern 2).

  ## Usage

      import PrimeYouth.Attendance.Adapters.Driven.Persistence.Queries.AttendanceQueries

      base_query()
      |> for_session(session_id)
      |> order_by_child()
      |> limit_results(50)
      |> Repo.all()
  """

  import Ecto.Query

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema
  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema

  @doc """
  Base query for attendance records.
  """
  def base_query do
    from(a in AttendanceRecordSchema)
  end

  @doc """
  Filter by attendance record ID.
  """
  def for_id(query, record_id) when is_binary(record_id) do
    from(a in query, where: a.id == ^record_id)
  end

  @doc """
  Filter by list of attendance record IDs (IN clause).
  """
  def for_ids(query, record_ids) when is_list(record_ids) do
    from(a in query, where: a.id in ^record_ids)
  end

  @doc """
  Filter by session ID.
  """
  def for_session(query, session_id) when is_binary(session_id) do
    from(a in query, where: a.session_id == ^session_id)
  end

  @doc """
  Filter by list of session IDs (IN clause).
  Useful for batch fetching attendance across multiple sessions.
  """
  def for_session_ids(query, session_ids) when is_list(session_ids) do
    from(a in query, where: a.session_id in ^session_ids)
  end

  @doc """
  Filter by child ID.
  """
  def for_child(query, child_id) when is_binary(child_id) do
    from(a in query, where: a.child_id == ^child_id)
  end

  @doc """
  Filter by parent ID.
  """
  def for_parent(query, parent_id) when is_binary(parent_id) do
    from(a in query, where: a.parent_id == ^parent_id)
  end

  @doc """
  Filter by session ID and child ID.
  """
  def for_session_and_child(query, session_id, child_id)
      when is_binary(session_id) and is_binary(child_id) do
    from(a in query, where: a.session_id == ^session_id and a.child_id == ^child_id)
  end

  @doc """
  Filter by attendance status.
  """
  def with_status(query, status) when is_binary(status) do
    from(a in query, where: a.status == ^status)
  end

  def with_status(query, status) when is_atom(status) do
    with_status(query, Atom.to_string(status))
  end

  @doc """
  JOIN with program_sessions table.
  Required for ordering by session date or accessing session fields.
  """
  def join_session(query) do
    from(a in query,
      join: s in ProgramSessionSchema,
      as: :session,
      on: a.session_id == s.id
    )
  end

  @doc """
  Order by child ID ascending.
  """
  def order_by_child(query) do
    from(a in query, order_by: [asc: a.child_id])
  end

  @doc """
  Order by check-in time.
  """
  def order_by_check_in(query, direction \\ :asc)

  def order_by_check_in(query, :asc) do
    from(a in query, order_by: [asc: a.check_in_at])
  end

  def order_by_check_in(query, :desc) do
    from(a in query, order_by: [desc: a.check_in_at])
  end

  @doc """
  Order by session date (requires join_session/1 first).
  """
  def order_by_session_date(query, direction \\ :desc)

  def order_by_session_date(query, :desc) do
    from([a, session: s] in query,
      order_by: [desc: s.session_date, desc: s.start_time]
    )
  end

  def order_by_session_date(query, :asc) do
    from([a, session: s] in query,
      order_by: [asc: s.session_date, asc: s.start_time]
    )
  end

  @doc """
  Limit query results.
  """
  def limit_results(query, limit) when is_integer(limit) and limit > 0 do
    from(a in query, limit: ^limit)
  end

  @doc """
  Select enriched fields with child name for provider view.
  Joins with children table and selects child first_name and last_name.
  """
  def with_child_name(query) do
    from(a in query,
      join: c in "children",
      on: a.child_id == c.id,
      select_merge: %{
        child_first_name: c.first_name,
        child_last_name: c.last_name
      }
    )
  end

  @doc """
  Select enriched fields for parent view.
  Requires session join. Includes session date, start time, and program name.
  """
  def with_parent_view_fields(query) do
    from([a, session: s] in query,
      join: p in PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema,
      on: s.program_id == p.id,
      join: c in "children",
      on: a.child_id == c.id,
      select_merge: %{
        session_date: s.session_date,
        session_start_time: s.start_time,
        program_name: p.title,
        child_first_name: c.first_name,
        child_last_name: c.last_name
      }
    )
  end
end
