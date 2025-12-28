defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Queries.AttendanceQueriesTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Queries.AttendanceQueries
  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema

  describe "base_query/0" do
    test "returns base query for AttendanceRecordSchema" do
      query = AttendanceQueries.base_query()

      assert %Ecto.Query{} = query
      assert query.from.source == {"attendance_records", AttendanceRecordSchema}
    end
  end

  describe "for_id/2" do
    test "adds WHERE clause for record ID" do
      record_id = Ecto.UUID.generate()

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.for_id(record_id)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
    end
  end

  describe "for_ids/2" do
    test "adds WHERE IN clause for record IDs" do
      record_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.for_ids(record_ids)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
    end
  end

  describe "for_session/2" do
    test "adds WHERE clause for session ID" do
      session_id = Ecto.UUID.generate()

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.for_session(session_id)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
    end
  end

  describe "for_session_ids/2" do
    test "adds WHERE IN clause for session IDs" do
      session_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.for_session_ids(session_ids)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
    end
  end

  describe "for_child/2" do
    test "adds WHERE clause for child ID" do
      child_id = Ecto.UUID.generate()

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.for_child(child_id)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
    end
  end

  describe "for_parent/2" do
    test "adds WHERE clause for parent ID" do
      parent_id = Ecto.UUID.generate()

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.for_parent(parent_id)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
    end
  end

  describe "for_session_and_child/3" do
    test "adds WHERE clause for both session ID and child ID" do
      session_id = Ecto.UUID.generate()
      child_id = Ecto.UUID.generate()

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.for_session_and_child(session_id, child_id)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
    end
  end

  describe "with_status/2" do
    test "adds WHERE clause for status as string" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.with_status("checked_in")

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
    end

    test "adds WHERE clause for status as atom" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.with_status(:checked_in)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
    end
  end

  describe "join_session/1" do
    test "adds JOIN with program_sessions table" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.join_session()

      assert %Ecto.Query{} = query
      assert length(query.joins) == 1
    end
  end

  describe "order_by_child/1" do
    test "orders by child_id ascending" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.order_by_child()

      assert [asc: {{:., [], [{:&, [], [0]}, :child_id]}, [], []}] =
               query.order_bys |> hd() |> Map.get(:expr)
    end
  end

  describe "order_by_check_in/2" do
    test "orders by check_in_at ascending by default" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.order_by_check_in()

      assert [asc: _] = query.order_bys |> hd() |> Map.get(:expr)
    end

    test "orders by check_in_at descending when specified" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.order_by_check_in(:desc)

      assert [desc: _] = query.order_bys |> hd() |> Map.get(:expr)
    end
  end

  describe "order_by_session_date/2" do
    test "orders by session_date and start_time descending by default" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.join_session()
        |> AttendanceQueries.order_by_session_date()

      assert [desc: _, desc: _] = query.order_bys |> hd() |> Map.get(:expr)
    end

    test "orders by session_date and start_time ascending when specified" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.join_session()
        |> AttendanceQueries.order_by_session_date(:asc)

      assert [asc: _, asc: _] = query.order_bys |> hd() |> Map.get(:expr)
    end
  end

  describe "limit_results/2" do
    test "adds LIMIT clause with specified limit" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.limit_results(10)

      assert %Ecto.Query{} = query
      assert query.limit != nil
    end

    test "works with different limit values" do
      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.limit_results(1)

      assert query.limit != nil

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.limit_results(100)

      assert query.limit != nil
    end
  end

  describe "query composition" do
    test "can compose filtering and ordering functions together" do
      session_id = Ecto.UUID.generate()

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.for_session(session_id)
        |> AttendanceQueries.with_status(:checked_in)
        |> AttendanceQueries.order_by_child()
        |> AttendanceQueries.limit_results(20)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 2
      assert length(query.order_bys) == 1
      assert query.limit != nil
    end

    test "can compose with session join and ordering" do
      child_id = Ecto.UUID.generate()

      query =
        AttendanceQueries.base_query()
        |> AttendanceQueries.for_child(child_id)
        |> AttendanceQueries.join_session()
        |> AttendanceQueries.order_by_session_date(:desc)
        |> AttendanceQueries.limit_results(50)

      assert %Ecto.Query{} = query
      assert length(query.wheres) == 1
      assert length(query.joins) == 1
      assert length(query.order_bys) == 1
      assert query.limit != nil
    end

    test "order of composition does not affect query structure" do
      session_id = Ecto.UUID.generate()

      query1 =
        AttendanceQueries.base_query()
        |> AttendanceQueries.order_by_child()
        |> AttendanceQueries.for_session(session_id)
        |> AttendanceQueries.limit_results(20)

      query2 =
        AttendanceQueries.base_query()
        |> AttendanceQueries.limit_results(20)
        |> AttendanceQueries.for_session(session_id)
        |> AttendanceQueries.order_by_child()

      assert length(query1.wheres) == length(query2.wheres)
      assert length(query1.order_bys) == length(query2.order_bys)
      assert query1.limit != nil
      assert query2.limit != nil
    end
  end
end
