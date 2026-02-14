defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Mappers.ProgramMapperTest do
  use KlassHero.DataCase, async: true

  import ExUnit.CaptureLog

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Mappers.ProgramMapper
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias KlassHero.ProgramCatalog.Domain.Models.Instructor
  alias KlassHero.ProgramCatalog.Domain.Models.Program

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
        icon_path: nil,
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      domain = ProgramMapper.to_domain(schema)

      assert %Program{} = domain
      assert domain.id == schema.id
      assert domain.title == "Art Class"
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
        icon_path: nil,
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      domain = ProgramMapper.to_domain(schema)

      assert domain.price == Decimal.new("99.99")
      assert Decimal.equal?(domain.price, Decimal.new("99.99"))
    end
  end

  describe "to_domain/1 instructor edge cases" do
    test "maps valid instructor fields to Instructor value object" do
      schema = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Coached Program",
        description: "Has instructor",
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        icon_path: nil,
        instructor_id: Ecto.UUID.generate(),
        instructor_name: "Jane Coach",
        instructor_headshot_url: "https://example.com/photo.jpg",
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      domain = ProgramMapper.to_domain(schema)

      assert %Instructor{} = domain.instructor
      assert domain.instructor.name == "Jane Coach"
      assert domain.instructor.headshot_url == "https://example.com/photo.jpg"
    end

    test "returns nil instructor without warning when instructor_id is nil" do
      log =
        capture_log(fn ->
          schema = %ProgramSchema{
            id: Ecto.UUID.generate(),
            title: "No Instructor Program",
            description: "No instructor assigned",
            schedule: "Mon-Fri",
            age_range: "6-12",
            price: Decimal.new("100.00"),
            pricing_period: "per week",
            spots_available: 10,
            icon_path: nil,
            instructor_id: nil,
            instructor_name: nil,
            instructor_headshot_url: nil,
            inserted_at: ~U[2024-01-01 10:00:00Z],
            updated_at: ~U[2024-01-01 10:00:00Z]
          }

          domain = ProgramMapper.to_domain(schema)
          assert domain.instructor == nil
        end)

      refute log =~ "[ProgramMapper]"
    end

    test "returns nil instructor and logs warning when instructor_name is nil" do
      schema = %ProgramSchema{
        id: Ecto.UUID.generate(),
        title: "Bad Data Program",
        description: "Instructor name missing",
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10,
        icon_path: nil,
        instructor_id: Ecto.UUID.generate(),
        instructor_name: nil,
        instructor_headshot_url: nil,
        inserted_at: ~U[2024-01-01 10:00:00Z],
        updated_at: ~U[2024-01-01 10:00:00Z]
      }

      log =
        capture_log(fn ->
          domain = ProgramMapper.to_domain(schema)
          assert domain.instructor == nil
        end)

      assert log =~ "[ProgramMapper] Instructor data invalid, skipping"
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
          description: "Has icon",
          schedule: "Mon",
          age_range: "6-10",
          price: Decimal.new("100.00"),
          pricing_period: "per week",
          spots_available: 10,
          icon_path: "/images/icon.svg",
          inserted_at: ~U[2024-01-01 10:00:00Z],
          updated_at: ~U[2024-01-01 10:00:00Z]
        },
        %ProgramSchema{
          id: Ecto.UUID.generate(),
          title: "Without Optional",
          description: "No icon",
          schedule: "Tue",
          age_range: "8-12",
          price: Decimal.new("75.00"),
          pricing_period: "per month",
          spots_available: 15,
          icon_path: nil,
          inserted_at: ~U[2024-01-01 10:00:00Z],
          updated_at: ~U[2024-01-01 10:00:00Z]
        }
      ]

      domains = ProgramMapper.to_domain_list(schemas)

      assert length(domains) == 2
      [with_optional, without_optional] = domains

      assert with_optional.icon_path == "/images/icon.svg"

      assert without_optional.icon_path == nil
    end
  end

  describe "to_schema/1" do
    test "includes provider_id in output" do
      program = %Program{
        id: "550e8400-e29b-41d4-a716-446655440000",
        title: "Test",
        description: "Desc",
        category: "arts",
        price: Decimal.new("50.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001",
        spots_available: 10
      }

      attrs = ProgramMapper.to_schema(program)
      assert attrs.provider_id == "660e8400-e29b-41d4-a716-446655440001"
    end

    test "includes all fields needed for create_changeset" do
      {:ok, instructor} = Instructor.new(%{id: "abc", name: "Jane"})

      program = %Program{
        id: nil,
        title: "Test",
        description: "Desc",
        category: "arts",
        price: Decimal.new("50.00"),
        provider_id: "660e8400-e29b-41d4-a716-446655440001",
        spots_available: 10,
        location: "Park",
        cover_image_url: "https://example.com/img.jpg",
        instructor: instructor
      }

      attrs = ProgramMapper.to_schema(program)
      assert attrs.provider_id == "660e8400-e29b-41d4-a716-446655440001"
      assert attrs.location == "Park"
      assert attrs.cover_image_url == "https://example.com/img.jpg"
      assert attrs.instructor_id == "abc"
      assert attrs.instructor_name == "Jane"
    end
  end
end
