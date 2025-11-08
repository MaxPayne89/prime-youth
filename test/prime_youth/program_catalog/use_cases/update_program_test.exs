defmodule PrimeYouth.ProgramCatalog.UseCases.UpdateProgramTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.ProgramCatalog.Domain.Entities.{Program, Provider}

  alias PrimeYouth.ProgramCatalog.Domain.ValueObjects.{
    AgeRange,
    ApprovalStatus,
    Pricing,
    ProgramCategory
  }

  alias PrimeYouth.ProgramCatalog.UseCases.UpdateProgram

  describe "execute/3" do
    setup do
      # Create test provider
      provider = %Provider{
        id: Ecto.UUID.generate(),
        name: "Test Provider",
        email: "test@provider.com",
        is_prime_youth: false,
        is_verified: true,
        user_id: Ecto.UUID.generate()
      }

      # Create existing program in draft status
      {:ok, category} = ProgramCategory.new("sports")
      {:ok, age_range} = AgeRange.new(6, 12)
      {:ok, pricing} = Pricing.new(299.99, "USD", "per_session", nil)
      {:ok, status} = ApprovalStatus.new("draft")

      {:ok, program} =
        Program.new(%{
          title: "Original Soccer Camp",
          description: "Original description of soccer camp",
          provider_id: provider.id,
          category: category,
          age_range: age_range,
          capacity: 20,
          current_enrollment: 0,
          pricing: pricing,
          status: status,
          is_prime_youth: false
        })

      {:ok, provider: provider, program: program}
    end

    test "updates program with valid attributes in draft status", %{
      provider: provider,
      program: program
    } do
      attrs = %{
        title: "Updated Soccer Camp",
        description: "Updated description with more details",
        category: :arts,
        age_range: %{min_age: 7, max_age: 13},
        capacity: 25,
        pricing: %{amount: 349.99, currency: "USD", payment_type: :per_session}
      }

      assert {:ok, %Program{} = updated_program} = UpdateProgram.execute(program, attrs, provider)

      assert updated_program.title == "Updated Soccer Camp"
      assert updated_program.description == "Updated description with more details"
      assert updated_program.category.value == "arts"
      assert updated_program.age_range.min_age == 7
      assert updated_program.age_range.max_age == 13
      assert updated_program.capacity == 25
      assert Decimal.equal?(updated_program.pricing.amount, Decimal.new("349.99"))
      assert updated_program.status.value == "draft"
    end

    test "submits draft program for approval", %{provider: provider, program: program} do
      attrs = %{
        submit_for_approval: true
      }

      assert {:ok, %Program{} = updated_program} = UpdateProgram.execute(program, attrs, provider)

      assert updated_program.status.value == "pending_approval"
      # Other fields remain unchanged
      assert updated_program.title == program.title
      assert updated_program.description == program.description
    end

    test "updates rejected program and resets to draft", %{provider: provider, program: _program} do
      # Create a rejected program
      {:ok, rejected_status} = ApprovalStatus.new("rejected")
      {:ok, category} = ProgramCategory.new("sports")
      {:ok, age_range} = AgeRange.new(6, 12)
      {:ok, pricing} = Pricing.new(299.99, "USD", "per_session", nil)

      {:ok, rejected_program} =
        Program.new(%{
          title: "Rejected Program",
          description: "This program was rejected",
          provider_id: provider.id,
          category: category,
          age_range: age_range,
          capacity: 20,
          current_enrollment: 0,
          pricing: pricing,
          status: rejected_status,
          is_prime_youth: false
        })

      attrs = %{
        title: "Updated After Rejection",
        description: "Updated description after addressing feedback"
      }

      assert {:ok, %Program{} = updated_program} =
               UpdateProgram.execute(rejected_program, attrs, provider)

      assert updated_program.title == "Updated After Rejection"
      assert updated_program.status.value == "draft"
    end

    test "allows partial updates (only some fields)", %{provider: provider, program: program} do
      attrs = %{
        title: "Just Update Title"
      }

      assert {:ok, %Program{} = updated_program} = UpdateProgram.execute(program, attrs, provider)

      assert updated_program.title == "Just Update Title"
      # Other fields unchanged
      assert updated_program.description == program.description
      assert updated_program.category == program.category
      assert updated_program.capacity == program.capacity
    end

    test "prevents updates to pending_approval programs", %{provider: provider, program: _program} do
      # Create pending_approval program
      {:ok, pending_status} = ApprovalStatus.new("pending_approval")
      {:ok, category} = ProgramCategory.new("sports")
      {:ok, age_range} = AgeRange.new(6, 12)
      {:ok, pricing} = Pricing.new(299.99, "USD", "per_session", nil)

      {:ok, pending_program} =
        Program.new(%{
          title: "Pending Program",
          description: "This program is pending approval",
          provider_id: provider.id,
          category: category,
          age_range: age_range,
          capacity: 20,
          current_enrollment: 0,
          pricing: pricing,
          status: pending_status,
          is_prime_youth: false
        })

      attrs = %{
        title: "Try to Update Pending"
      }

      assert {:error, :cannot_update_pending} =
               UpdateProgram.execute(pending_program, attrs, provider)
    end

    test "prevents updates to approved programs", %{provider: provider, program: _program} do
      # Create approved program
      {:ok, approved_status} = ApprovalStatus.new("approved")
      {:ok, category} = ProgramCategory.new("sports")
      {:ok, age_range} = AgeRange.new(6, 12)
      {:ok, pricing} = Pricing.new(299.99, "USD", "per_session", nil)

      {:ok, approved_program} =
        Program.new(%{
          title: "Approved Program",
          description: "This program is approved",
          provider_id: provider.id,
          category: category,
          age_range: age_range,
          capacity: 20,
          current_enrollment: 0,
          pricing: pricing,
          status: approved_status,
          is_prime_youth: false
        })

      attrs = %{
        title: "Try to Update Approved"
      }

      assert {:error, :cannot_update_approved} =
               UpdateProgram.execute(approved_program, attrs, provider)
    end

    test "returns error when provider doesn't own the program", %{
      provider: _provider,
      program: program
    } do
      other_provider = %Provider{
        id: Ecto.UUID.generate(),
        name: "Other Provider",
        email: "other@provider.com",
        is_prime_youth: false,
        is_verified: true,
        user_id: Ecto.UUID.generate()
      }

      attrs = %{
        title: "Unauthorized Update"
      }

      assert {:error, :provider_mismatch} =
               UpdateProgram.execute(program, attrs, other_provider)
    end

    test "returns error with invalid title", %{provider: provider, program: program} do
      attrs = %{
        title: "AB"
        # Too short (< 3 characters)
      }

      assert {:error, :invalid_title} = UpdateProgram.execute(program, attrs, provider)
    end

    test "returns error with invalid description", %{provider: provider, program: program} do
      attrs = %{
        description: "Short"
        # Too short (< 10 characters)
      }

      assert {:error, :invalid_description} = UpdateProgram.execute(program, attrs, provider)
    end

    test "returns error with invalid capacity", %{provider: provider, program: program} do
      attrs = %{
        capacity: 0
        # Must be > 0
      }

      assert {:error, :invalid_capacity} = UpdateProgram.execute(program, attrs, provider)
    end

    test "returns error with invalid category", %{provider: provider, program: program} do
      attrs = %{
        category: :invalid_category
      }

      assert {:error, error_msg} = UpdateProgram.execute(program, attrs, provider)
      assert error_msg =~ "Invalid category"
    end

    test "returns error with invalid age range", %{provider: provider, program: program} do
      attrs = %{
        age_range: %{min_age: 15, max_age: 10}
        # min > max is invalid
      }

      assert {:error, error_msg} = UpdateProgram.execute(program, attrs, provider)
      assert error_msg =~ "Min age cannot be greater than max age"
    end

    test "returns error when provider is not verified", %{provider: _provider, program: program} do
      unverified_provider = %Provider{
        id: program.provider_id,
        # Match the program's provider ID
        name: "Unverified Provider",
        email: "unverified@provider.com",
        is_prime_youth: false,
        is_verified: false,
        user_id: Ecto.UUID.generate()
      }

      attrs = %{
        title: "Try to Update"
      }

      assert {:error, :provider_not_verified} =
               UpdateProgram.execute(program, attrs, unverified_provider)
    end

    test "prevents capacity decrease below current enrollment", %{
      provider: provider,
      program: _program
    } do
      # Create program with current enrollment
      {:ok, category} = ProgramCategory.new("sports")
      {:ok, age_range} = AgeRange.new(6, 12)
      {:ok, pricing} = Pricing.new(299.99, "USD", "per_session", nil)
      {:ok, status} = ApprovalStatus.new("draft")

      {:ok, enrolled_program} =
        Program.new(%{
          title: "Enrolled Program",
          description: "Program with existing enrollments",
          provider_id: provider.id,
          category: category,
          age_range: age_range,
          capacity: 20,
          current_enrollment: 15,
          # 15 kids already enrolled
          pricing: pricing,
          status: status,
          is_prime_youth: false
        })

      attrs = %{
        capacity: 10
        # Try to reduce below current enrollment
      }

      assert {:error, :capacity_below_enrollment} =
               UpdateProgram.execute(enrolled_program, attrs, provider)
    end

    test "allows capacity decrease to match current enrollment", %{
      provider: provider,
      program: _program
    } do
      # Create program with current enrollment
      {:ok, category} = ProgramCategory.new("sports")
      {:ok, age_range} = AgeRange.new(6, 12)
      {:ok, pricing} = Pricing.new(299.99, "USD", "per_session", nil)
      {:ok, status} = ApprovalStatus.new("draft")

      {:ok, enrolled_program} =
        Program.new(%{
          title: "Enrolled Program",
          description: "Program with existing enrollments",
          provider_id: provider.id,
          category: category,
          age_range: age_range,
          capacity: 20,
          current_enrollment: 15,
          pricing: pricing,
          status: status,
          is_prime_youth: false
        })

      attrs = %{
        capacity: 15
        # Match current enrollment exactly
      }

      assert {:ok, %Program{} = updated_program} =
               UpdateProgram.execute(enrolled_program, attrs, provider)

      assert updated_program.capacity == 15
    end
  end
end
