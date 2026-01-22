defmodule KlassHero.Enrollment.Application.UseCases.CreateEnrollmentTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Application.UseCases.CreateEnrollment
  alias KlassHero.Enrollment.Domain.Models.Enrollment

  describe "execute/1" do
    test "creates enrollment with valid params" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      params = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id
      }

      assert {:ok, enrollment} = CreateEnrollment.execute(params)
      assert %Enrollment{} = enrollment
      assert enrollment.program_id == program.id
      assert enrollment.child_id == child.id
      assert enrollment.parent_id == child.parent_id
      assert enrollment.status == :pending
    end

    test "defaults status to pending" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      params = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id
      }

      {:ok, enrollment} = CreateEnrollment.execute(params)

      assert enrollment.status == :pending
    end

    test "defaults enrolled_at to current time" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      params = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id
      }

      before = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, enrollment} = CreateEnrollment.execute(params)
      after_time = DateTime.utc_now() |> DateTime.add(1, :second)

      assert DateTime.compare(enrollment.enrolled_at, before) in [:gt, :eq]
      assert DateTime.compare(enrollment.enrolled_at, after_time) in [:lt, :eq]
    end

    test "accepts optional fee amounts" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      params = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id,
        subtotal: Decimal.new("100.00"),
        vat_amount: Decimal.new("19.00"),
        card_fee_amount: Decimal.new("2.00"),
        total_amount: Decimal.new("121.00")
      }

      {:ok, enrollment} = CreateEnrollment.execute(params)

      assert enrollment.subtotal == Decimal.new("100.00")
      assert enrollment.vat_amount == Decimal.new("19.00")
      assert enrollment.card_fee_amount == Decimal.new("2.00")
      assert enrollment.total_amount == Decimal.new("121.00")
    end

    test "accepts payment_method" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      params = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id,
        payment_method: "transfer"
      }

      {:ok, enrollment} = CreateEnrollment.execute(params)

      assert enrollment.payment_method == "transfer"
    end

    test "accepts special_requirements" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      params = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id,
        special_requirements: "Allergic to peanuts"
      }

      {:ok, enrollment} = CreateEnrollment.execute(params)

      assert enrollment.special_requirements == "Allergic to peanuts"
    end

    test "returns duplicate_resource error for duplicate active enrollment" do
      existing = insert(:enrollment_schema, status: "pending")

      params = %{
        program_id: existing.program_id,
        child_id: existing.child_id,
        parent_id: existing.parent_id
      }

      assert {:error, :duplicate_resource} = CreateEnrollment.execute(params)
    end

    test "allows new enrollment after previous one cancelled" do
      cancelled = insert(:enrollment_schema, status: "cancelled")

      params = %{
        program_id: cancelled.program_id,
        child_id: cancelled.child_id,
        parent_id: cancelled.parent_id
      }

      assert {:ok, enrollment} = CreateEnrollment.execute(params)
      assert enrollment.status == :pending
    end

    test "returns changeset error for missing required fields" do
      params = %{}

      assert {:error, %Ecto.Changeset{}} = CreateEnrollment.execute(params)
    end

    test "accepts custom enrolled_at" do
      program = insert(:program_schema)
      child = insert(:child_schema)
      enrolled_at = ~U[2025-01-15 10:00:00Z]

      params = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id,
        enrolled_at: enrolled_at
      }

      {:ok, enrollment} = CreateEnrollment.execute(params)

      assert enrollment.enrolled_at == enrolled_at
    end

    test "accepts custom status" do
      program = insert(:program_schema)
      child = insert(:child_schema)

      params = %{
        program_id: program.id,
        child_id: child.id,
        parent_id: child.parent_id,
        status: "confirmed"
      }

      {:ok, enrollment} = CreateEnrollment.execute(params)

      assert enrollment.status == :confirmed
    end
  end
end
