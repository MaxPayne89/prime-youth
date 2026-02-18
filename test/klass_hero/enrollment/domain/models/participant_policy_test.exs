defmodule KlassHero.Enrollment.Domain.Models.ParticipantPolicyTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Models.ParticipantPolicy

  describe "new/1" do
    test "creates policy with all fields" do
      assert {:ok, policy} =
               ParticipantPolicy.new(%{
                 program_id: "prog-123",
                 min_age_months: 48,
                 max_age_months: 144,
                 allowed_genders: ["male", "female"],
                 min_grade: 1,
                 max_grade: 4,
                 eligibility_at: "program_start"
               })

      assert policy.program_id == "prog-123"
      assert policy.min_age_months == 48
      assert policy.max_age_months == 144
      assert policy.allowed_genders == ["male", "female"]
      assert policy.min_grade == 1
      assert policy.max_grade == 4
      assert policy.eligibility_at == "program_start"
    end

    test "creates policy with no restrictions (only program_id required)" do
      assert {:ok, policy} = ParticipantPolicy.new(%{program_id: "prog-123"})

      assert policy.program_id == "prog-123"
      assert policy.min_age_months == nil
      assert policy.max_age_months == nil
      assert policy.allowed_genders == []
      assert policy.min_grade == nil
      assert policy.max_grade == nil
      assert policy.eligibility_at == "registration"
    end

    test "rejects min_age > max_age" do
      assert {:error, errors} =
               ParticipantPolicy.new(%{
                 program_id: "prog-123",
                 min_age_months: 144,
                 max_age_months: 48
               })

      assert "minimum age must not exceed maximum age" in errors
    end

    test "rejects min_grade > max_grade" do
      assert {:error, errors} =
               ParticipantPolicy.new(%{
                 program_id: "prog-123",
                 min_grade: 8,
                 max_grade: 4
               })

      assert "minimum grade must not exceed maximum grade" in errors
    end

    test "rejects invalid gender values in allowed_genders" do
      assert {:error, errors} =
               ParticipantPolicy.new(%{
                 program_id: "prog-123",
                 allowed_genders: ["male", "unknown"]
               })

      assert Enum.any?(errors, &String.contains?(&1, "invalid gender"))
    end

    test "requires program_id" do
      assert {:error, errors} = ParticipantPolicy.new(%{min_age_months: 48})
      assert "program ID is required" in errors
    end

    test "defaults eligibility_at to registration" do
      assert {:ok, policy} = ParticipantPolicy.new(%{program_id: "prog-123"})
      assert policy.eligibility_at == "registration"
    end

    test "defaults allowed_genders to empty list when nil" do
      assert {:ok, policy} =
               ParticipantPolicy.new(%{program_id: "prog-123", allowed_genders: nil})

      assert policy.allowed_genders == []
    end

    test "defaults eligibility_at to registration when nil" do
      assert {:ok, policy} =
               ParticipantPolicy.new(%{program_id: "prog-123", eligibility_at: nil})

      assert policy.eligibility_at == "registration"
    end
  end

  describe "eligible?/2" do
    test "no restrictions — always eligible" do
      {:ok, policy} = ParticipantPolicy.new(%{program_id: "p"})
      participant = %{age_months: 72, gender: "male", grade: 3}

      assert {:ok, :eligible} = ParticipantPolicy.eligible?(policy, participant)
    end

    test "age within range — eligible" do
      {:ok, policy} =
        ParticipantPolicy.new(%{program_id: "p", min_age_months: 48, max_age_months: 144})

      assert {:ok, :eligible} =
               ParticipantPolicy.eligible?(policy, %{age_months: 72, gender: "male", grade: nil})
    end

    test "age below min — ineligible with reason" do
      {:ok, policy} = ParticipantPolicy.new(%{program_id: "p", min_age_months: 60})

      assert {:error, reasons} =
               ParticipantPolicy.eligible?(policy, %{age_months: 48, gender: "male", grade: nil})

      assert Enum.any?(reasons, &String.contains?(&1, "too young"))
      assert Enum.any?(reasons, &String.contains?(&1, "60"))
    end

    test "age above max — ineligible with reason" do
      {:ok, policy} = ParticipantPolicy.new(%{program_id: "p", max_age_months: 120})

      assert {:error, reasons} =
               ParticipantPolicy.eligible?(policy, %{
                 age_months: 144,
                 gender: "male",
                 grade: nil
               })

      assert Enum.any?(reasons, &String.contains?(&1, "too old"))
      assert Enum.any?(reasons, &String.contains?(&1, "120"))
    end

    test "gender in allowed list — eligible" do
      {:ok, policy} =
        ParticipantPolicy.new(%{program_id: "p", allowed_genders: ["male", "female"]})

      assert {:ok, :eligible} =
               ParticipantPolicy.eligible?(policy, %{age_months: 72, gender: "female", grade: nil})
    end

    test "gender not in allowed list — ineligible with reason" do
      {:ok, policy} = ParticipantPolicy.new(%{program_id: "p", allowed_genders: ["female"]})

      assert {:error, reasons} =
               ParticipantPolicy.eligible?(policy, %{age_months: 72, gender: "male", grade: nil})

      assert Enum.any?(reasons, &String.contains?(&1, "gender"))
      assert Enum.any?(reasons, &String.contains?(&1, "female"))
    end

    test "empty allowed_genders — eligible (no restriction)" do
      {:ok, policy} = ParticipantPolicy.new(%{program_id: "p", allowed_genders: []})

      assert {:ok, :eligible} =
               ParticipantPolicy.eligible?(policy, %{
                 age_months: 72,
                 gender: "diverse",
                 grade: nil
               })
    end

    test "grade within range — eligible" do
      {:ok, policy} =
        ParticipantPolicy.new(%{program_id: "p", min_grade: 1, max_grade: 4})

      assert {:ok, :eligible} =
               ParticipantPolicy.eligible?(policy, %{age_months: 72, gender: "male", grade: 3})
    end

    test "grade below min — ineligible" do
      {:ok, policy} =
        ParticipantPolicy.new(%{program_id: "p", min_grade: 3, max_grade: 6})

      assert {:error, reasons} =
               ParticipantPolicy.eligible?(policy, %{age_months: 72, gender: "male", grade: 1})

      assert Enum.any?(reasons, &String.contains?(&1, "grade"))
    end

    test "grade above max — ineligible" do
      {:ok, policy} =
        ParticipantPolicy.new(%{program_id: "p", min_grade: 1, max_grade: 4})

      assert {:error, reasons} =
               ParticipantPolicy.eligible?(policy, %{age_months: 72, gender: "male", grade: 6})

      assert Enum.any?(reasons, &String.contains?(&1, "grade"))
    end

    test "grade nil when restriction exists — ineligible" do
      {:ok, policy} =
        ParticipantPolicy.new(%{program_id: "p", min_grade: 1, max_grade: 4})

      assert {:error, reasons} =
               ParticipantPolicy.eligible?(policy, %{age_months: 72, gender: "male", grade: nil})

      assert Enum.any?(reasons, &String.contains?(&1, "school grade is required"))
    end

    test "multiple failures — all reasons returned" do
      {:ok, policy} =
        ParticipantPolicy.new(%{
          program_id: "p",
          min_age_months: 60,
          allowed_genders: ["female"],
          min_grade: 3
        })

      assert {:error, reasons} =
               ParticipantPolicy.eligible?(policy, %{age_months: 48, gender: "male", grade: 1})

      assert length(reasons) == 3
      assert Enum.any?(reasons, &String.contains?(&1, "too young"))
      assert Enum.any?(reasons, &String.contains?(&1, "gender"))
      assert Enum.any?(reasons, &String.contains?(&1, "grade"))
    end

    test "only min_age set (no max) — eligible if above min" do
      {:ok, policy} = ParticipantPolicy.new(%{program_id: "p", min_age_months: 48})

      assert {:ok, :eligible} =
               ParticipantPolicy.eligible?(policy, %{age_months: 200, gender: "male", grade: nil})
    end

    test "only max_age set (no min) — eligible if below max" do
      {:ok, policy} = ParticipantPolicy.new(%{program_id: "p", max_age_months: 144})

      assert {:ok, :eligible} =
               ParticipantPolicy.eligible?(policy, %{age_months: 12, gender: "male", grade: nil})
    end
  end
end
