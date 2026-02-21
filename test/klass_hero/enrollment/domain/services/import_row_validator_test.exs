defmodule KlassHero.Enrollment.Domain.Services.ImportRowValidatorTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Services.ImportRowValidator

  # -- helpers ---------------------------------------------------------------

  @provider_id "provider-uuid-1"

  @programs_by_title %{
    "Ballsports & Parkour" => "program-uuid-1",
    "Organic Arts" => "program-uuid-2"
  }

  defp context do
    %{
      provider_id: @provider_id,
      programs_by_title: @programs_by_title
    }
  end

  defp valid_row do
    %{
      child_first_name: "Avyan",
      child_last_name: "Srivastava",
      child_date_of_birth: ~D[2016-01-01],
      guardian_email: "vaibhavinuk@gmail.com",
      guardian_first_name: "Vaibhav",
      guardian_last_name: "Srivastava",
      guardian2_email: nil,
      guardian2_first_name: nil,
      guardian2_last_name: nil,
      school_grade: 3,
      school_name: nil,
      medical_conditions: nil,
      nut_allergy: false,
      consent_photo_marketing: false,
      consent_photo_social_media: false,
      program_name: "Ballsports & Parkour",
      instructor_name: nil,
      season: "Berlin International School 24/25: Semester 2"
    }
  end

  # -- happy path ------------------------------------------------------------

  describe "validate/2 happy path" do
    test "valid row returns enriched map with program_id and provider_id" do
      assert {:ok, result} = ImportRowValidator.validate(valid_row(), context())

      assert result.program_id == "program-uuid-1"
      assert result.provider_id == @provider_id
      assert result.child_first_name == "Avyan"
      assert result.child_last_name == "Srivastava"
      assert result.child_date_of_birth == ~D[2016-01-01]
      assert result.guardian_email == "vaibhavinuk@gmail.com"
    end

    test "removes program_name, instructor_name, and season from output" do
      assert {:ok, result} = ImportRowValidator.validate(valid_row(), context())

      refute Map.has_key?(result, :program_name)
      refute Map.has_key?(result, :instructor_name)
      refute Map.has_key?(result, :season)
    end

    test "valid row with second guardian email passes" do
      row = %{valid_row() | guardian2_email: "second@example.com"}

      assert {:ok, result} = ImportRowValidator.validate(row, context())
      assert result.guardian2_email == "second@example.com"
    end
  end

  # -- required fields -------------------------------------------------------

  describe "required field validation" do
    test "missing child_first_name returns error" do
      row = %{valid_row() | child_first_name: nil}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:child_first_name, "is required"} in errors
    end

    test "empty child_first_name returns error" do
      row = %{valid_row() | child_first_name: ""}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:child_first_name, "is required"} in errors
    end

    test "missing child_last_name returns error" do
      row = %{valid_row() | child_last_name: nil}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:child_last_name, "is required"} in errors
    end

    test "missing child_date_of_birth returns error" do
      row = %{valid_row() | child_date_of_birth: nil}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:child_date_of_birth, "is required"} in errors
    end

    test "missing guardian_email returns error" do
      row = %{valid_row() | guardian_email: nil}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:guardian_email, "is required"} in errors
    end

    test "missing program_name returns error" do
      row = %{valid_row() | program_name: nil}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:program_name, "is required"} in errors
    end
  end

  # -- email format ----------------------------------------------------------

  describe "email format validation" do
    test "invalid guardian_email returns error" do
      row = %{valid_row() | guardian_email: "not-an-email"}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:guardian_email, "must be a valid email"} in errors
    end

    test "guardian_email with spaces returns error" do
      row = %{valid_row() | guardian_email: "has space@example.com"}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:guardian_email, "must be a valid email"} in errors
    end

    test "invalid guardian2_email returns error when present" do
      row = %{valid_row() | guardian2_email: "bad-email"}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:guardian2_email, "must be a valid email"} in errors
    end

    test "nil guardian2_email is valid (optional)" do
      row = %{valid_row() | guardian2_email: nil}

      assert {:ok, _result} = ImportRowValidator.validate(row, context())
    end
  end

  # -- program existence -----------------------------------------------------

  describe "program existence validation" do
    test "unknown program returns error" do
      row = %{valid_row() | program_name: "Nonexistent Program"}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:program_name, "program not found"} in errors
    end
  end

  # -- date of birth ---------------------------------------------------------

  describe "date of birth validation" do
    test "future date of birth returns error" do
      row = %{valid_row() | child_date_of_birth: Date.add(Date.utc_today(), 1)}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:child_date_of_birth, "must be in the past"} in errors
    end

    test "today's date returns error" do
      row = %{valid_row() | child_date_of_birth: Date.utc_today()}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:child_date_of_birth, "must be in the past"} in errors
    end
  end

  # -- school grade ----------------------------------------------------------

  describe "school grade validation" do
    test "grade 0 returns error" do
      row = %{valid_row() | school_grade: 0}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:school_grade, "must be between 1 and 13"} in errors
    end

    test "grade 14 returns error" do
      row = %{valid_row() | school_grade: 14}

      assert {:error, errors} = ImportRowValidator.validate(row, context())
      assert {:school_grade, "must be between 1 and 13"} in errors
    end

    test "nil grade is valid (optional)" do
      row = %{valid_row() | school_grade: nil}

      assert {:ok, _result} = ImportRowValidator.validate(row, context())
    end

    test "grade 1 is valid" do
      row = %{valid_row() | school_grade: 1}

      assert {:ok, result} = ImportRowValidator.validate(row, context())
      assert result.school_grade == 1
    end

    test "grade 13 is valid" do
      row = %{valid_row() | school_grade: 13}

      assert {:ok, result} = ImportRowValidator.validate(row, context())
      assert result.school_grade == 13
    end
  end

  # -- error accumulation ----------------------------------------------------

  describe "multiple errors accumulated" do
    test "returns all errors for a row with multiple problems" do
      row = %{
        valid_row()
        | child_first_name: nil,
          guardian_email: "bad",
          program_name: "Nonexistent",
          school_grade: 0
      }

      assert {:error, errors} = ImportRowValidator.validate(row, context())

      assert {:child_first_name, "is required"} in errors
      assert {:guardian_email, "must be a valid email"} in errors
      assert {:program_name, "program not found"} in errors
      assert {:school_grade, "must be between 1 and 13"} in errors

      # Verify at least 4 errors accumulated
      assert length(errors) >= 4
    end
  end
end
