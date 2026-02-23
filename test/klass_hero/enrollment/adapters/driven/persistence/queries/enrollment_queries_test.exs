defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Queries.EnrollmentQueriesTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Queries.EnrollmentQueries
  alias KlassHero.Repo

  describe "base/0" do
    test "returns a queryable for enrollments" do
      query = EnrollmentQueries.base()

      assert %Ecto.Query{} = query
    end
  end

  describe "by_parent/2" do
    test "filters enrollments by parent_id" do
      enrollment1 = insert(:enrollment_schema)
      enrollment2 = insert(:enrollment_schema)

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_parent(enrollment1.parent_id)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == enrollment1.id
      refute Enum.any?(result, &(&1.id == enrollment2.id))
    end

    test "returns empty list when no matching parent" do
      _enrollment = insert(:enrollment_schema)

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_parent(Ecto.UUID.generate())
        |> Repo.all()

      assert result == []
    end
  end

  describe "by_child/2" do
    test "filters enrollments by child_id" do
      enrollment1 = insert(:enrollment_schema)
      enrollment2 = insert(:enrollment_schema)

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_child(enrollment1.child_id)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == enrollment1.id
      refute Enum.any?(result, &(&1.id == enrollment2.id))
    end
  end

  describe "by_program/2" do
    test "filters enrollments by program_id" do
      enrollment1 = insert(:enrollment_schema)
      enrollment2 = insert(:enrollment_schema)

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_program(enrollment1.program_id)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == enrollment1.id
      refute Enum.any?(result, &(&1.id == enrollment2.id))
    end
  end

  describe "by_status/2" do
    test "filters by single status string" do
      pending = insert(:enrollment_schema, status: "pending")
      _confirmed = insert(:enrollment_schema, status: "confirmed")

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_status("pending")
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == pending.id
    end

    test "filters by list of statuses" do
      pending = insert(:enrollment_schema, status: "pending")
      confirmed = insert(:enrollment_schema, status: "confirmed")
      _completed = insert(:enrollment_schema, status: "completed")

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_status(["pending", "confirmed"])
        |> Repo.all()

      ids = Enum.map(result, & &1.id)
      assert length(result) == 2
      assert pending.id in ids
      assert confirmed.id in ids
    end
  end

  describe "active_only/1" do
    test "filters to pending and confirmed enrollments only" do
      pending = insert(:enrollment_schema, status: "pending")
      confirmed = insert(:enrollment_schema, status: "confirmed")
      _completed = insert(:enrollment_schema, status: "completed")
      _cancelled = insert(:enrollment_schema, status: "cancelled")

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.active_only()
        |> Repo.all()

      ids = Enum.map(result, & &1.id)
      assert length(result) == 2
      assert pending.id in ids
      assert confirmed.id in ids
    end
  end

  describe "by_date_range/3" do
    test "filters enrollments within date range inclusive" do
      jan_15 = ~U[2025-01-15 10:00:00Z]
      jan_20 = ~U[2025-01-20 10:00:00Z]
      jan_25 = ~U[2025-01-25 10:00:00Z]

      in_range = insert(:enrollment_schema, enrolled_at: jan_20)
      _before_range = insert(:enrollment_schema, enrolled_at: jan_15)
      _after_range = insert(:enrollment_schema, enrolled_at: jan_25)

      start_date = ~D[2025-01-18]
      end_date = ~D[2025-01-22]

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_date_range(start_date, end_date)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == in_range.id
    end

    test "includes start and end date boundaries" do
      start_of_day = ~U[2025-01-18 00:00:00Z]
      end_of_day = ~U[2025-01-22 23:59:59Z]

      at_start = insert(:enrollment_schema, enrolled_at: start_of_day)
      at_end = insert(:enrollment_schema, enrolled_at: end_of_day)

      start_date = ~D[2025-01-18]
      end_date = ~D[2025-01-22]

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_date_range(start_date, end_date)
        |> Repo.all()

      ids = Enum.map(result, & &1.id)
      assert at_start.id in ids
      assert at_end.id in ids
    end
  end

  describe "order_by_enrolled_at_desc/1" do
    test "orders enrollments by enrolled_at descending" do
      old = insert(:enrollment_schema, enrolled_at: ~U[2025-01-10 10:00:00Z])
      recent = insert(:enrollment_schema, enrolled_at: ~U[2025-01-20 10:00:00Z])
      middle = insert(:enrollment_schema, enrolled_at: ~U[2025-01-15 10:00:00Z])

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.order_by_enrolled_at_desc()
        |> Repo.all()

      ids = Enum.map(result, & &1.id)
      assert ids == [recent.id, middle.id, old.id]
    end
  end

  describe "count/1" do
    test "returns count of matching enrollments" do
      parent_schema = insert(:parent_profile_schema)
      program_schema = insert(:program_schema)
      {child_schema1, _parent} = insert_child_with_guardian(parent: parent_schema)
      {child_schema2, _parent} = insert_child_with_guardian(parent: parent_schema)

      insert(:enrollment_schema,
        parent_id: parent_schema.id,
        program_id: program_schema.id,
        child_id: child_schema1.id,
        status: "pending"
      )

      insert(:enrollment_schema,
        parent_id: parent_schema.id,
        program_id: program_schema.id,
        child_id: child_schema2.id,
        status: "confirmed"
      )

      count =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_parent(parent_schema.id)
        |> EnrollmentQueries.count()
        |> Repo.one()

      assert count == 2
    end

    test "returns 0 when no matches" do
      count =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_parent(Ecto.UUID.generate())
        |> EnrollmentQueries.count()
        |> Repo.one()

      assert count == 0
    end
  end

  describe "query composition" do
    test "composes multiple filters correctly" do
      parent_schema = insert(:parent_profile_schema)
      program_schema = insert(:program_schema)
      {child_schema, _parent} = insert_child_with_guardian(parent: parent_schema)

      target =
        insert(:enrollment_schema,
          parent_id: parent_schema.id,
          program_id: program_schema.id,
          child_id: child_schema.id,
          status: "pending",
          enrolled_at: ~U[2025-01-15 10:00:00Z]
        )

      _other =
        insert(:enrollment_schema,
          status: "confirmed"
        )

      result =
        EnrollmentQueries.base()
        |> EnrollmentQueries.by_parent(parent_schema.id)
        |> EnrollmentQueries.by_program(program_schema.id)
        |> EnrollmentQueries.active_only()
        |> EnrollmentQueries.by_date_range(~D[2025-01-01], ~D[2025-01-31])
        |> EnrollmentQueries.order_by_enrolled_at_desc()
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == target.id
    end
  end
end
