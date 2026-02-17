defmodule KlassHero.Enrollment.Domain.Models.EnrollmentPolicyTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  describe "new/1" do
    test "creates policy with valid min and max" do
      assert {:ok, policy} =
               EnrollmentPolicy.new(%{
                 program_id: "prog-123",
                 min_enrollment: 5,
                 max_enrollment: 20
               })

      assert policy.program_id == "prog-123"
      assert policy.min_enrollment == 5
      assert policy.max_enrollment == 20
    end

    test "creates policy with only max" do
      assert {:ok, policy} =
               EnrollmentPolicy.new(%{program_id: "prog-123", max_enrollment: 20})

      assert policy.min_enrollment == nil
      assert policy.max_enrollment == 20
    end

    test "creates policy with only min" do
      assert {:ok, policy} =
               EnrollmentPolicy.new(%{program_id: "prog-123", min_enrollment: 5})

      assert policy.min_enrollment == 5
      assert policy.max_enrollment == nil
    end

    test "rejects when min > max" do
      assert {:error, errors} =
               EnrollmentPolicy.new(%{
                 program_id: "prog-123",
                 min_enrollment: 25,
                 max_enrollment: 10
               })

      assert "minimum enrollment must not exceed maximum enrollment" in errors
    end

    test "rejects when min < 1" do
      assert {:error, errors} =
               EnrollmentPolicy.new(%{program_id: "prog-123", min_enrollment: 0})

      assert "minimum enrollment must be at least 1" in errors
    end

    test "rejects when max < 1" do
      assert {:error, errors} =
               EnrollmentPolicy.new(%{program_id: "prog-123", max_enrollment: 0})

      assert "maximum enrollment must be at least 1" in errors
    end

    test "rejects when neither min nor max is set" do
      assert {:error, errors} = EnrollmentPolicy.new(%{program_id: "prog-123"})
      assert "at least one of minimum or maximum enrollment is required" in errors
    end

    test "rejects missing program_id" do
      assert {:error, errors} = EnrollmentPolicy.new(%{max_enrollment: 20})
      assert "program ID is required" in errors
    end
  end

  describe "has_capacity?/2" do
    test "returns true when count < max" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", max_enrollment: 10})
      assert EnrollmentPolicy.has_capacity?(policy, 5) == true
    end

    test "returns false when count >= max" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", max_enrollment: 10})
      assert EnrollmentPolicy.has_capacity?(policy, 10) == false
    end

    test "returns true when no max set (min only)" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", min_enrollment: 5})
      assert EnrollmentPolicy.has_capacity?(policy, 999) == true
    end
  end

  describe "remaining_capacity/2" do
    test "returns remaining spots when count < max" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", max_enrollment: 10})
      assert EnrollmentPolicy.remaining_capacity(policy, 3) == 7
    end

    test "returns 0 when count >= max (never negative)" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", max_enrollment: 5})
      assert EnrollmentPolicy.remaining_capacity(policy, 5) == 0
      assert EnrollmentPolicy.remaining_capacity(policy, 8) == 0
    end

    test "returns :unlimited when no max set (min only)" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", min_enrollment: 5})
      assert EnrollmentPolicy.remaining_capacity(policy, 999) == :unlimited
    end
  end

  describe "meets_minimum?/2" do
    test "returns true when count >= min" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", min_enrollment: 5})
      assert EnrollmentPolicy.meets_minimum?(policy, 5) == true
    end

    test "returns false when count < min" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", min_enrollment: 5})
      assert EnrollmentPolicy.meets_minimum?(policy, 3) == false
    end

    test "returns true when no min set" do
      {:ok, policy} = EnrollmentPolicy.new(%{program_id: "p", max_enrollment: 20})
      assert EnrollmentPolicy.meets_minimum?(policy, 0) == true
    end
  end
end
