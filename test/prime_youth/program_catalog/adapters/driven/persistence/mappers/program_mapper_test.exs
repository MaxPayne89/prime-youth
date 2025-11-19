defmodule PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Mappers.ProgramMapperTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Mappers.ProgramMapper
  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias PrimeYouth.ProgramCatalog.Domain.Models.Program

  describe "to_domain/1" do
    test "converts schema to domain model with all fields" do
      schema = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Summer Soccer Camp",
        description: "Fun soccer activities for kids of all skill levels",
        schedule: "Mon-Fri 9AM-12PM",
        age_range: "6-12",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 20,
        gradient_class: "from-blue-500 to-purple-600",
        icon_path: "/images/soccer.svg",
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      domain = ProgramMapper.to_domain(schema)

      assert %Program{} = domain
      assert domain.id == schema.id
      assert domain.title == "Summer Soccer Camp"
      assert domain.description == "Fun soccer activities for kids of all skill levels"
      assert domain.schedule == "Mon-Fri 9AM-12PM"
      assert domain.age_range == "6-12"
      assert domain.price == Decimal.new("150.00")
      assert domain.pricing_period == "per week"
      assert domain.spots_available == 20
      assert domain.gradient_class == "from-blue-500 to-purple-600"
      assert domain.icon_path == "/images/soccer.svg"
    end

    test "converts schema to domain model without optional fields" do
      schema = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Art Class",
        description: "Creative art activities",
        schedule: "Saturdays 10AM-12PM",
        age_range: "8-14",
        price: Decimal.new("75.00"),
        pricing_period: "per month",
        spots_available: 15,
        gradient_class: nil,
        icon_path: nil,
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      domain = ProgramMapper.to_domain(schema)

      assert %Program{} = domain
      assert domain.id == schema.id
      assert domain.title == "Art Class"
      assert domain.gradient_class == nil
      assert domain.icon_path == nil
    end

    test "converts schema with price = 0 (free program)" do
      schema = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Community Day",
        description: "Free community event",
        schedule: "Sunday 2PM-5PM",
        age_range: "All ages",
        price: Decimal.new("0.00"),
        pricing_period: "per session",
        spots_available: 100,
        gradient_class: "from-green-500 to-teal-600",
        icon_path: "/images/community.svg",
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      domain = ProgramMapper.to_domain(schema)

      assert %Program{} = domain
      assert domain.price == Decimal.new("0.00")
      assert Program.free?(domain)
    end

    test "converts schema with spots_available = 0 (sold out)" do
      schema = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Popular Camp",
        description: "Sold out camp",
        schedule: "All week",
        age_range: "10-15",
        price: Decimal.new("200.00"),
        pricing_period: "per week",
        spots_available: 0,
        gradient_class: "from-red-500 to-orange-600",
        icon_path: "/images/camp.svg",
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      domain = ProgramMapper.to_domain(schema)

      assert %Program{} = domain
      assert domain.spots_available == 0
      assert Program.sold_out?(domain)
    end

    test "preserves Decimal precision for price" do
      schema = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Program",
        description: "Description",
        schedule: "Schedule",
        age_range: "6-12",
        price: Decimal.new("99.99"),
        pricing_period: "per session",
        spots_available: 10,
        gradient_class: nil,
        icon_path: nil,
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      domain = ProgramMapper.to_domain(schema)

      assert domain.price == Decimal.new("99.99")
      assert Decimal.equal?(domain.price, Decimal.new("99.99"))
    end
  end

  describe "to_domain_list/1" do
    test "converts list of schemas to list of domain models" do
      schemas = [
        %ProgramSchema{
          id: Ecto.UUID.generate(),
          title: "Program A",
          description: "Description A",
          schedule: "Mon-Fri",
          age_range: "6-10",
          price: Decimal.new("100.00"),
          pricing_period: "per week",
          spots_available: 15,
          gradient_class: "from-blue-500 to-purple-600",
          icon_path: "/images/a.svg",
          inserted_at: ~U[2024-01-01 10:00:00Z],
          updated_at: ~U[2024-01-01 10:00:00Z]
        },
        %ProgramSchema{
          id: Ecto.UUID.generate(),
          title: "Program B",
          description: "Description B",
          schedule: "Saturdays",
          age_range: "8-12",
          price: Decimal.new("75.00"),
          pricing_period: "per month",
          spots_available: 20,
          gradient_class: "from-green-500 to-teal-600",
          icon_path: "/images/b.svg",
          inserted_at: ~U[2024-01-01 10:00:00Z],
          updated_at: ~U[2024-01-01 10:00:00Z]
        },
        %ProgramSchema{
          id: Ecto.UUID.generate(),
          title: "Program C",
          description: "Description C",
          schedule: "Sundays",
          age_range: "10-14",
          price: Decimal.new("0.00"),
          pricing_period: "per session",
          spots_available: 0,
          gradient_class: nil,
          icon_path: nil,
          inserted_at: ~U[2024-01-01 10:00:00Z],
          updated_at: ~U[2024-01-01 10:00:00Z]
        }
      ]

      domains = ProgramMapper.to_domain_list(schemas)

      assert length(domains) == 3
      assert Enum.all?(domains, &match?(%Program{}, &1))

      [program_a, program_b, program_c] = domains

      assert program_a.title == "Program A"
      assert program_a.price == Decimal.new("100.00")
      assert program_a.spots_available == 15

      assert program_b.title == "Program B"
      assert program_b.price == Decimal.new("75.00")
      assert program_b.spots_available == 20

      assert program_c.title == "Program C"
      assert program_c.price == Decimal.new("0.00")
      assert program_c.spots_available == 0
      assert Program.free?(program_c)
      assert Program.sold_out?(program_c)
    end

    test "converts empty list to empty list" do
      assert ProgramMapper.to_domain_list([]) == []
    end

    test "maintains order of schemas in domain list" do
      schema_1 = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "First",
        description: "Desc",
        schedule: "Mon",
        age_range: "6-10",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        gradient_class: nil,
        icon_path: nil,
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      schema_2 = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Second",
        description: "Desc",
        schedule: "Tue",
        age_range: "6-10",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        gradient_class: nil,
        icon_path: nil,
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      schema_3 = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Third",
        description: "Desc",
        schedule: "Wed",
        age_range: "6-10",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        gradient_class: nil,
        icon_path: nil,
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      schemas = [schema_1, schema_2, schema_3]
      domains = ProgramMapper.to_domain_list(schemas)

      assert [first, second, third] = domains
      assert first.title == "First"
      assert second.title == "Second"
      assert third.title == "Third"
    end

    test "handles mix of programs with and without optional fields" do
      schemas = [
        %ProgramSchema{
          id: Ecto.UUID.generate(),
          title: "With Optional",
          description: "Has gradient and icon",
          schedule: "Mon",
          age_range: "6-10",
          price: Decimal.new("100.00"),
          pricing_period: "per week",
          spots_available: 10,
          gradient_class: "from-blue-500 to-purple-600",
          icon_path: "/images/icon.svg",
          inserted_at: ~U[2024-01-01 10:00:00Z],
          updated_at: ~U[2024-01-01 10:00:00Z]
        },
        %ProgramSchema{
          id: Ecto.UUID.generate(),
          title: "Without Optional",
          description: "No gradient or icon",
          schedule: "Tue",
          age_range: "8-12",
          price: Decimal.new("75.00"),
          pricing_period: "per month",
          spots_available: 15,
          gradient_class: nil,
          icon_path: nil,
          inserted_at: ~U[2024-01-01 10:00:00Z],
          updated_at: ~U[2024-01-01 10:00:00Z]
        }
      ]

      domains = ProgramMapper.to_domain_list(schemas)

      assert length(domains) == 2
      [with_optional, without_optional] = domains

      assert with_optional.gradient_class == "from-blue-500 to-purple-600"
      assert with_optional.icon_path == "/images/icon.svg"

      assert without_optional.gradient_class == nil
      assert without_optional.icon_path == nil
    end
  end
end
