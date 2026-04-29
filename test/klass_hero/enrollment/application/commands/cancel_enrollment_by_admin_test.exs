defmodule KlassHero.Enrollment.Application.Commands.CancelEnrollmentByAdminTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Application.Commands.CancelEnrollmentByAdmin
  alias KlassHero.Enrollment.Domain.Models.Enrollment

  describe "execute/3" do
    test "cancels a pending enrollment and returns domain entity" do
      schema = insert(:enrollment_schema, status: :pending)
      admin_id = Ecto.UUID.generate()

      assert {:ok, enrollment} =
               CancelEnrollmentByAdmin.execute(schema.id, admin_id, "Duplicate booking")

      assert %Enrollment{} = enrollment
      assert enrollment.status == :cancelled
      assert enrollment.cancellation_reason == "Duplicate booking"
      assert enrollment.cancelled_at != nil
    end

    test "cancels a confirmed enrollment" do
      schema = insert(:enrollment_schema, status: :confirmed)
      admin_id = Ecto.UUID.generate()

      assert {:ok, enrollment} =
               CancelEnrollmentByAdmin.execute(schema.id, admin_id, "Parent requested")

      assert enrollment.status == :cancelled
    end

    test "returns invalid_status_transition for completed enrollment" do
      schema = insert(:enrollment_schema, status: :completed)
      admin_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               CancelEnrollmentByAdmin.execute(schema.id, admin_id, "Too late")
    end

    test "returns invalid_status_transition for already cancelled enrollment" do
      schema = insert(:enrollment_schema, status: :cancelled)
      admin_id = Ecto.UUID.generate()

      assert {:error, :invalid_status_transition} =
               CancelEnrollmentByAdmin.execute(schema.id, admin_id, "Already gone")
    end

    test "returns not_found for nonexistent enrollment" do
      admin_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               CancelEnrollmentByAdmin.execute(Ecto.UUID.generate(), admin_id, "Nope")
    end

    test "returns invalid_reason for empty reason" do
      schema = insert(:enrollment_schema, status: :pending)
      admin_id = Ecto.UUID.generate()

      assert {:error, :invalid_reason} =
               CancelEnrollmentByAdmin.execute(schema.id, admin_id, "")
    end

    test "returns invalid_reason for nil reason" do
      schema = insert(:enrollment_schema, status: :pending)
      admin_id = Ecto.UUID.generate()

      assert {:error, :invalid_reason} =
               CancelEnrollmentByAdmin.execute(schema.id, admin_id, nil)
    end
  end
end
