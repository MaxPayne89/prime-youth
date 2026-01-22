defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.EnrollmentRepository
  alias KlassHero.Enrollment.Domain.Models.Enrollment

  describe "create/1" do
    test "creates enrollment with valid attributes" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      attrs = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id,
        status: "pending",
        enrolled_at: DateTime.utc_now(),
        subtotal: Decimal.new("100.00"),
        vat_amount: Decimal.new("19.00"),
        card_fee_amount: Decimal.new("2.00"),
        total_amount: Decimal.new("121.00"),
        payment_method: "card"
      }

      assert {:ok, enrollment} = EnrollmentRepository.create(attrs)
      assert %Enrollment{} = enrollment
      assert enrollment.program_id == program.id
      assert enrollment.child_id == child.id
      assert enrollment.parent_id == child.parent_id
      assert enrollment.status == :pending
    end

    test "returns domain entity with string IDs" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      attrs = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id,
        status: "pending",
        enrolled_at: DateTime.utc_now()
      }

      {:ok, enrollment} = EnrollmentRepository.create(attrs)

      assert is_binary(enrollment.id)
      assert is_binary(enrollment.program_id)
      assert is_binary(enrollment.child_id)
      assert is_binary(enrollment.parent_id)
    end

    test "returns error when required fields are missing" do
      attrs = %{}

      assert {:error, changeset} = EnrollmentRepository.create(attrs)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end

    test "returns duplicate_resource error for active enrollment duplicate" do
      enrollment = insert(:enrollment_schema, status: "pending")

      attrs = %{
        program_id: enrollment.program_id,
        child_id: enrollment.child_id,
        parent_id: enrollment.parent_id,
        status: "pending",
        enrolled_at: DateTime.utc_now()
      }

      assert {:error, :duplicate_resource} = EnrollmentRepository.create(attrs)
    end

    test "allows duplicate for cancelled enrollment" do
      cancelled = insert(:enrollment_schema, status: "cancelled")

      attrs = %{
        program_id: cancelled.program_id,
        child_id: cancelled.child_id,
        parent_id: cancelled.parent_id,
        status: "pending",
        enrolled_at: DateTime.utc_now()
      }

      assert {:ok, _enrollment} = EnrollmentRepository.create(attrs)
    end

    test "allows duplicate for completed enrollment" do
      completed = insert(:enrollment_schema, status: "completed")

      attrs = %{
        program_id: completed.program_id,
        child_id: completed.child_id,
        parent_id: completed.parent_id,
        status: "pending",
        enrolled_at: DateTime.utc_now()
      }

      assert {:ok, _enrollment} = EnrollmentRepository.create(attrs)
    end
  end

  describe "get_by_id/1" do
    test "returns enrollment when found" do
      enrollment_schema = insert(:enrollment_schema)

      assert {:ok, enrollment} = EnrollmentRepository.get_by_id(enrollment_schema.id)
      assert %Enrollment{} = enrollment
      assert enrollment.id == to_string(enrollment_schema.id)
    end

    test "returns domain entity with correct status atom" do
      enrollment_schema = insert(:enrollment_schema, status: "confirmed")

      {:ok, enrollment} = EnrollmentRepository.get_by_id(enrollment_schema.id)

      assert enrollment.status == :confirmed
    end

    test "returns not_found when enrollment does not exist" do
      assert {:error, :not_found} = EnrollmentRepository.get_by_id(Ecto.UUID.generate())
    end
  end

  describe "list_by_parent/1" do
    test "returns all enrollments for parent" do
      parent = insert(:parent_profile_schema)
      child1 = insert(:child_schema, parent_id: parent.id)
      child2 = insert(:child_schema, parent_id: parent.id)

      enrollment1 = insert(:enrollment_schema, parent_id: parent.id, child_id: child1.id)
      enrollment2 = insert(:enrollment_schema, parent_id: parent.id, child_id: child2.id)
      _other = insert(:enrollment_schema)

      enrollments = EnrollmentRepository.list_by_parent(parent.id)

      assert length(enrollments) == 2
      ids = Enum.map(enrollments, & &1.id)
      assert to_string(enrollment1.id) in ids
      assert to_string(enrollment2.id) in ids
    end

    test "returns enrollments ordered by enrolled_at descending" do
      parent = insert(:parent_profile_schema)
      child = insert(:child_schema, parent_id: parent.id)

      old =
        insert(:enrollment_schema,
          parent_id: parent.id,
          child_id: child.id,
          enrolled_at: ~U[2025-01-10 10:00:00Z]
        )

      recent =
        insert(:enrollment_schema,
          parent_id: parent.id,
          child_id: child.id,
          enrolled_at: ~U[2025-01-20 10:00:00Z],
          status: "confirmed"
        )

      middle =
        insert(:enrollment_schema,
          parent_id: parent.id,
          child_id: child.id,
          enrolled_at: ~U[2025-01-15 10:00:00Z],
          status: "completed"
        )

      enrollments = EnrollmentRepository.list_by_parent(parent.id)

      ids = Enum.map(enrollments, & &1.id)
      assert ids == [to_string(recent.id), to_string(middle.id), to_string(old.id)]
    end

    test "returns empty list when no enrollments" do
      assert EnrollmentRepository.list_by_parent(Ecto.UUID.generate()) == []
    end

    test "returns domain entities" do
      enrollment_schema = insert(:enrollment_schema)

      [enrollment] = EnrollmentRepository.list_by_parent(enrollment_schema.parent_id)

      assert %Enrollment{} = enrollment
      assert is_atom(enrollment.status)
    end
  end

  describe "count_monthly_bookings/3" do
    test "counts active enrollments in date range" do
      parent = insert(:parent_profile_schema)
      child = insert(:child_schema, parent_id: parent.id)

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        status: "pending",
        enrolled_at: ~U[2025-01-15 10:00:00Z]
      )

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        status: "confirmed",
        enrolled_at: ~U[2025-01-20 10:00:00Z]
      )

      count =
        EnrollmentRepository.count_monthly_bookings(parent.id, ~D[2025-01-01], ~D[2025-01-31])

      assert count == 2
    end

    test "excludes completed and cancelled enrollments" do
      parent = insert(:parent_profile_schema)
      child = insert(:child_schema, parent_id: parent.id)

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        status: "pending",
        enrolled_at: ~U[2025-01-15 10:00:00Z]
      )

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        status: "completed",
        enrolled_at: ~U[2025-01-16 10:00:00Z]
      )

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        status: "cancelled",
        enrolled_at: ~U[2025-01-17 10:00:00Z]
      )

      count =
        EnrollmentRepository.count_monthly_bookings(parent.id, ~D[2025-01-01], ~D[2025-01-31])

      assert count == 1
    end

    test "excludes enrollments outside date range" do
      parent = insert(:parent_profile_schema)
      child = insert(:child_schema, parent_id: parent.id)

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        status: "pending",
        enrolled_at: ~U[2024-12-15 10:00:00Z]
      )

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        status: "pending",
        enrolled_at: ~U[2025-01-15 10:00:00Z]
      )

      insert(:enrollment_schema,
        parent_id: parent.id,
        child_id: child.id,
        status: "confirmed",
        enrolled_at: ~U[2025-02-15 10:00:00Z]
      )

      count =
        EnrollmentRepository.count_monthly_bookings(parent.id, ~D[2025-01-01], ~D[2025-01-31])

      assert count == 1
    end

    test "returns 0 when no matching enrollments" do
      count =
        EnrollmentRepository.count_monthly_bookings(
          Ecto.UUID.generate(),
          ~D[2025-01-01],
          ~D[2025-01-31]
        )

      assert count == 0
    end
  end
end
