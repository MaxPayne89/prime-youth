defmodule PrimeYouth.ProgramCatalog.UseCases.CreateProgramTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.ProgramCatalog.Domain.Entities.{Program, Provider}
  alias PrimeYouth.ProgramCatalog.UseCases.CreateProgram

  describe "execute/2" do
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

      {:ok, provider: provider}
    end

    test "creates program with valid attributes for external provider", %{provider: provider} do
      attrs = %{
        title: "Summer Soccer Camp",
        description: "Fun and engaging soccer camp for kids",
        provider_id: provider.id,
        category: :sports,
        age_range: %{min_age: 6, max_age: 12},
        capacity: 20,
        pricing: %{amount: 299.99, currency: "USD", payment_type: :per_session},
        is_prime_youth: false
      }

      assert {:ok, %Program{} = program} = CreateProgram.execute(attrs, provider)

      assert program.title == "Summer Soccer Camp"
      assert program.description == "Fun and engaging soccer camp for kids"
      assert program.provider_id == provider.id
      assert program.category.value == "sports"
      assert program.capacity == 20
      assert program.current_enrollment == 0
      assert program.status.value == "draft"
      assert program.is_prime_youth == false
      assert is_nil(program.archived_at)
    end

    test "creates program with pending_approval status when external provider submits", %{
      provider: provider
    } do
      attrs = %{
        title: "Art Workshop",
        description: "Creative art workshop for children",
        provider_id: provider.id,
        category: :arts,
        age_range: %{min_age: 8, max_age: 14},
        capacity: 15,
        pricing: %{amount: 199.99, currency: "USD", payment_type: :per_session},
        is_prime_youth: false,
        submit_for_approval: true
      }

      assert {:ok, %Program{} = program} = CreateProgram.execute(attrs, provider)

      assert program.status.value == "pending_approval"
    end

    test "creates program with approved status for Prime Youth provider", %{provider: _provider} do
      prime_youth_provider = %Provider{
        id: Ecto.UUID.generate(),
        name: "Prime Youth",
        email: "programs@primeyouth.com",
        is_prime_youth: true,
        is_verified: true,
        user_id: Ecto.UUID.generate()
      }

      attrs = %{
        title: "Leadership Workshop",
        description: "Developing young leaders",
        provider_id: prime_youth_provider.id,
        category: :leadership,
        age_range: %{min_age: 12, max_age: 16},
        capacity: 30,
        pricing: %{amount: 100.0, currency: "USD", payment_type: :per_program},
        is_prime_youth: true
      }

      assert {:ok, %Program{} = program} = CreateProgram.execute(attrs, prime_youth_provider)

      # Prime Youth programs bypass approval workflow
      assert program.status.value == "approved"
      assert program.is_prime_youth == true
    end

    test "returns error with invalid title", %{provider: provider} do
      attrs = %{
        title: "AB",
        # Too short (< 3 characters)
        description: "Fun soccer camp",
        provider_id: provider.id,
        category: :sports,
        age_range: %{min_age: 6, max_age: 12},
        capacity: 20,
        pricing: %{amount: 299.99, currency: "USD", payment_type: :per_session}
      }

      assert {:error, :invalid_title} = CreateProgram.execute(attrs, provider)
    end

    test "returns error with invalid description", %{provider: provider} do
      attrs = %{
        title: "Summer Camp",
        description: "Short",
        # Too short (< 10 characters)
        provider_id: provider.id,
        category: :sports,
        age_range: %{min_age: 6, max_age: 12},
        capacity: 20,
        pricing: %{amount: 299.99, currency: "USD", payment_type: :per_session}
      }

      assert {:error, :invalid_description} = CreateProgram.execute(attrs, provider)
    end

    test "returns error with invalid capacity", %{provider: provider} do
      attrs = %{
        title: "Summer Camp",
        description: "Fun summer activities",
        provider_id: provider.id,
        category: :sports,
        age_range: %{min_age: 6, max_age: 12},
        capacity: 0,
        # Must be > 0
        pricing: %{amount: 299.99, currency: "USD", payment_type: :per_session}
      }

      assert {:error, :invalid_capacity} = CreateProgram.execute(attrs, provider)
    end

    test "returns error with invalid category", %{provider: provider} do
      attrs = %{
        title: "Summer Camp",
        description: "Fun summer activities",
        provider_id: provider.id,
        category: :invalid_category,
        age_range: %{min_age: 6, max_age: 12},
        capacity: 20,
        pricing: %{amount: 299.99, currency: "USD", payment_type: :per_session}
      }

      assert {:error, error_msg} = CreateProgram.execute(attrs, provider)
      assert error_msg =~ "Invalid category"
    end

    test "returns error with invalid age range", %{provider: provider} do
      attrs = %{
        title: "Summer Camp",
        description: "Fun summer activities",
        provider_id: provider.id,
        category: :sports,
        age_range: %{min_age: 15, max_age: 10},
        # min > max is invalid
        capacity: 20,
        pricing: %{amount: 299.99, currency: "USD", payment_type: :per_session}
      }

      assert {:error, error_msg} = CreateProgram.execute(attrs, provider)
      assert error_msg =~ "Min age cannot be greater than max age"
    end

    test "returns error when provider is not verified", %{provider: _provider} do
      unverified_provider = %Provider{
        id: Ecto.UUID.generate(),
        name: "Unverified Provider",
        email: "unverified@provider.com",
        is_prime_youth: false,
        is_verified: false,
        user_id: Ecto.UUID.generate()
      }

      attrs = %{
        title: "Summer Camp",
        description: "Fun summer activities",
        provider_id: unverified_provider.id,
        category: :sports,
        age_range: %{min_age: 6, max_age: 12},
        capacity: 20,
        pricing: %{amount: 299.99, currency: "USD", payment_type: :per_session}
      }

      assert {:error, :provider_not_verified} = CreateProgram.execute(attrs, unverified_provider)
    end

    test "returns error when provider_id mismatch", %{provider: provider} do
      other_provider_id = Ecto.UUID.generate()

      attrs = %{
        title: "Summer Camp",
        description: "Fun summer activities",
        provider_id: other_provider_id,
        # Different from provider param
        category: :sports,
        age_range: %{min_age: 6, max_age: 12},
        capacity: 20,
        pricing: %{amount: 299.99, currency: "USD", payment_type: :per_session}
      }

      assert {:error, :provider_mismatch} = CreateProgram.execute(attrs, provider)
    end
  end
end
