defmodule KlassHero.Enrollment.Domain.Models.EnrollmentTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Models.Enrollment

  describe "new/1" do
    test "creates enrollment with valid attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        status: :pending,
        enrolled_at: DateTime.utc_now()
      }

      assert {:ok, enrollment} = Enrollment.new(attrs)
      assert enrollment.id == attrs.id
      assert enrollment.program_id == attrs.program_id
      assert enrollment.child_id == attrs.child_id
      assert enrollment.parent_id == attrs.parent_id
      assert enrollment.status == :pending
    end

    test "defaults status to pending when not provided" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        enrolled_at: DateTime.utc_now()
      }

      assert {:ok, enrollment} = Enrollment.new(attrs)
      assert enrollment.status == :pending
    end

    test "defaults enrolled_at to now when not provided" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate()
      }

      before = DateTime.utc_now()
      {:ok, enrollment} = Enrollment.new(attrs)
      after_time = DateTime.utc_now()

      assert DateTime.compare(enrollment.enrolled_at, before) in [:gt, :eq]
      assert DateTime.compare(enrollment.enrolled_at, after_time) in [:lt, :eq]
    end

    test "returns error when id is missing" do
      attrs = %{
        program_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate()
      }

      assert {:error, ["Missing required fields"]} = Enrollment.new(attrs)
    end

    test "returns error when program_id is empty string" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: "",
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate()
      }

      assert {:error, errors} = Enrollment.new(attrs)
      assert "program_id cannot be empty" in errors
    end

    test "returns error when status is invalid" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        status: :invalid_status
      }

      assert {:error, errors} = Enrollment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "Status must be one of:"))
    end

    test "returns error when payment_method is invalid" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        payment_method: "invalid"
      }

      assert {:error, errors} = Enrollment.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "Payment method must be one of:"))
    end

    test "allows nil payment_method" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        child_id: Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate(),
        payment_method: nil
      }

      assert {:ok, enrollment} = Enrollment.new(attrs)
      assert is_nil(enrollment.payment_method)
    end

    test "accepts valid payment methods" do
      for method <- ["card", "transfer"] do
        attrs = %{
          id: Ecto.UUID.generate(),
          program_id: Ecto.UUID.generate(),
          child_id: Ecto.UUID.generate(),
          parent_id: Ecto.UUID.generate(),
          payment_method: method
        }

        assert {:ok, enrollment} = Enrollment.new(attrs)
        assert enrollment.payment_method == method
      end
    end
  end

  describe "confirm/1" do
    test "confirms a pending enrollment" do
      {:ok, enrollment} = build_enrollment(:pending)

      assert {:ok, confirmed} = Enrollment.confirm(enrollment)
      assert confirmed.status == :confirmed
      assert confirmed.confirmed_at != nil
    end

    test "returns error when enrollment is not pending" do
      {:ok, enrollment} = build_enrollment(:confirmed)

      assert {:error, :invalid_status_transition} = Enrollment.confirm(enrollment)
    end
  end

  describe "complete/1" do
    test "completes a confirmed enrollment" do
      {:ok, enrollment} = build_enrollment(:confirmed)

      assert {:ok, completed} = Enrollment.complete(enrollment)
      assert completed.status == :completed
      assert completed.completed_at != nil
    end

    test "returns error when enrollment is not confirmed" do
      {:ok, enrollment} = build_enrollment(:pending)

      assert {:error, :invalid_status_transition} = Enrollment.complete(enrollment)
    end
  end

  describe "cancel/2" do
    test "cancels a pending enrollment" do
      {:ok, enrollment} = build_enrollment(:pending)

      assert {:ok, cancelled} = Enrollment.cancel(enrollment, "Changed mind")
      assert cancelled.status == :cancelled
      assert cancelled.cancelled_at != nil
      assert cancelled.cancellation_reason == "Changed mind"
    end

    test "cancels a confirmed enrollment" do
      {:ok, enrollment} = build_enrollment(:confirmed)

      assert {:ok, cancelled} = Enrollment.cancel(enrollment)
      assert cancelled.status == :cancelled
      assert cancelled.cancelled_at != nil
    end

    test "returns error when enrollment is already completed" do
      {:ok, enrollment} = build_enrollment(:completed)

      assert {:error, :invalid_status_transition} = Enrollment.cancel(enrollment)
    end

    test "returns error when enrollment is already cancelled" do
      {:ok, enrollment} = build_enrollment(:cancelled)

      assert {:error, :invalid_status_transition} = Enrollment.cancel(enrollment)
    end
  end

  describe "predicates" do
    test "pending?/1 returns true for pending enrollment" do
      {:ok, enrollment} = build_enrollment(:pending)
      assert Enrollment.pending?(enrollment)
      refute Enrollment.confirmed?(enrollment)
    end

    test "confirmed?/1 returns true for confirmed enrollment" do
      {:ok, enrollment} = build_enrollment(:confirmed)
      assert Enrollment.confirmed?(enrollment)
      refute Enrollment.pending?(enrollment)
    end

    test "completed?/1 returns true for completed enrollment" do
      {:ok, enrollment} = build_enrollment(:completed)
      assert Enrollment.completed?(enrollment)
      refute Enrollment.confirmed?(enrollment)
    end

    test "cancelled?/1 returns true for cancelled enrollment" do
      {:ok, enrollment} = build_enrollment(:cancelled)
      assert Enrollment.cancelled?(enrollment)
      refute Enrollment.pending?(enrollment)
    end

    test "active?/1 returns true for pending or confirmed enrollments" do
      {:ok, pending} = build_enrollment(:pending)
      {:ok, confirmed} = build_enrollment(:confirmed)
      {:ok, completed} = build_enrollment(:completed)
      {:ok, cancelled} = build_enrollment(:cancelled)

      assert Enrollment.active?(pending)
      assert Enrollment.active?(confirmed)
      refute Enrollment.active?(completed)
      refute Enrollment.active?(cancelled)
    end
  end

  describe "valid_statuses/0" do
    test "returns all valid statuses" do
      statuses = Enrollment.valid_statuses()

      assert :pending in statuses
      assert :confirmed in statuses
      assert :completed in statuses
      assert :cancelled in statuses
      assert length(statuses) == 4
    end
  end

  describe "valid_payment_methods/0" do
    test "returns all valid payment methods" do
      methods = Enrollment.valid_payment_methods()

      assert "card" in methods
      assert "transfer" in methods
      assert length(methods) == 2
    end
  end

  defp build_enrollment(status) do
    base_attrs = %{
      id: Ecto.UUID.generate(),
      program_id: Ecto.UUID.generate(),
      child_id: Ecto.UUID.generate(),
      parent_id: Ecto.UUID.generate(),
      status: status,
      enrolled_at: DateTime.utc_now()
    }

    attrs =
      case status do
        :confirmed ->
          Map.put(base_attrs, :confirmed_at, DateTime.utc_now())

        :completed ->
          Map.merge(base_attrs, %{
            confirmed_at: DateTime.utc_now(),
            completed_at: DateTime.utc_now()
          })

        :cancelled ->
          Map.put(base_attrs, :cancelled_at, DateTime.utc_now())

        _ ->
          base_attrs
      end

    Enrollment.new(attrs)
  end
end
