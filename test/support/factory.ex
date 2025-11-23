defmodule PrimeYouth.Factory do
  @moduledoc """
  ExMachina factory for creating test data across the Prime Youth application.

  This factory provides builders for both domain entities and Ecto schemas,
  following the DDD/Ports & Adapters architecture.

  ## Usage

      # Build domain entity (for use case tests)
      program = build(:program)
      program = build(:program, title: "Custom Title")

      # Build Ecto schema (for repository tests)
      schema = build(:program_schema)

      # Insert into database (for integration tests)
      program = insert(:program_schema)

      # Named variations
      program = build(:soccer_program)
      program = build(:dance_program)

      # Build lists
      programs = build_list(3, :program)
  """

  use ExMachina.Ecto, repo: PrimeYouth.Repo

  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias PrimeYouth.ProgramCatalog.Domain.Models.Program

  @doc """
  Factory for creating Program domain entities (pure Elixir structs).

  Used in use case tests where we don't need database persistence.

  ## Examples

      program = build(:program)
      program = build(:program, title: "Soccer Camp", spots_available: 15)
  """
  def program_factory do
    %Program{
      id:
        sequence(
          :program_id,
          &"550e8400-e29b-41d4-a716-44665544#{String.pad_leading("#{&1}", 4, "0")}"
        ),
      title: sequence(:program_title, &"Test Program #{&1}"),
      description: "A great program for kids to learn and have fun",
      schedule: "Mon-Fri 3-5pm",
      age_range: "6-10 years",
      price: Decimal.new("100.00"),
      pricing_period: "per month",
      spots_available: 10,
      gradient_class: "bg-gradient-to-br from-blue-400 to-green-500",
      icon_path: "/images/icons/default.svg",
      inserted_at: ~U[2025-01-01 12:00:00Z],
      updated_at: ~U[2025-01-01 12:00:00Z]
    }
  end

  @doc """
  Factory for creating ProgramSchema Ecto schemas.

  Used in repository and integration tests where we need database persistence.

  ## Examples

      schema = build(:program_schema)
      schema = insert(:program_schema, title: "Art Class")
  """
  def program_schema_factory do
    %ProgramSchema{
      id: Ecto.UUID.generate(),
      title: sequence(:program_schema_title, &"Test Program #{&1}"),
      description: "A great program for kids to learn and have fun",
      schedule: "Mon-Fri 3-5pm",
      age_range: "6-10 years",
      price: Decimal.new("100.00"),
      pricing_period: "per month",
      spots_available: 10,
      gradient_class: "bg-gradient-to-br from-blue-400 to-green-500",
      icon_path: "/images/icons/default.svg"
    }
  end

  @doc """
  Soccer program variant - commonly used in filter tests.
  """
  def soccer_program_factory do
    struct!(
      program_factory(),
      %{
        id: "550e8400-e29b-41d4-a716-446655440001",
        title: "After School Soccer",
        description: "Learn soccer fundamentals in a fun environment",
        schedule: "Mon-Wed 3-5pm",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        spots_available: 12,
        gradient_class: "bg-gradient-to-br from-green-400 to-blue-500",
        icon_path: "/images/icons/soccer.svg"
      }
    )
  end

  @doc """
  Dance program variant - commonly used in filter tests.
  """
  def dance_program_factory do
    struct!(
      program_factory(),
      %{
        id: "550e8400-e29b-41d4-a716-446655440002",
        title: "Summer Dance Camp",
        description: "Express yourself through creative movement and dance",
        schedule: "Tue-Thu 4-6pm",
        age_range: "7-12 years",
        price: Decimal.new("120.00"),
        spots_available: 8,
        gradient_class: "bg-gradient-to-br from-purple-400 to-pink-500",
        icon_path: "/images/icons/dance.svg"
      }
    )
  end

  @doc """
  Yoga program variant - commonly used in filter tests.
  """
  def yoga_program_factory do
    struct!(
      program_factory(),
      %{
        id: "550e8400-e29b-41d4-a716-446655440003",
        title: "Kids Yoga Flow",
        description: "Mindfulness and movement for young yogis",
        schedule: "Sat 9-10am",
        age_range: "5-8 years",
        price: Decimal.new("80.00"),
        spots_available: 15,
        gradient_class: "bg-gradient-to-br from-teal-400 to-cyan-500",
        icon_path: "/images/icons/yoga.svg"
      }
    )
  end

  @doc """
  Basketball program variant - commonly used in filter tests.
  """
  def basketball_program_factory do
    struct!(
      program_factory(),
      %{
        id: "550e8400-e29b-41d4-a716-446655440004",
        title: "Basketball Training",
        description: "Develop basketball skills and teamwork",
        schedule: "Mon-Fri 4-6pm",
        age_range: "8-14 years",
        price: Decimal.new("200.00"),
        spots_available: 16,
        gradient_class: "bg-gradient-to-br from-orange-400 to-red-500",
        icon_path: "/images/icons/basketball.svg"
      }
    )
  end

  @doc """
  Art program variant with special characters - tests normalization.
  """
  def art_program_factory do
    struct!(
      program_factory(),
      %{
        id: "550e8400-e29b-41d4-a716-446655440005",
        title: "Art! & Crafts",
        description: "Creative arts and crafts exploration",
        schedule: "Wed 3-5pm",
        age_range: "5-10 years",
        price: Decimal.new("90.00"),
        spots_available: 12,
        gradient_class: "bg-gradient-to-br from-yellow-400 to-orange-500",
        icon_path: "/images/icons/art.svg"
      }
    )
  end

  @doc """
  Build a standard set of sample programs for filter testing.

  Returns a list of 5 diverse programs commonly used in filter tests.

  ## Example

      programs = sample_programs()
      # Returns [soccer, dance, yoga, basketball, art]
  """
  def sample_programs do
    [
      build(:soccer_program),
      build(:dance_program),
      build(:yoga_program),
      build(:basketball_program),
      build(:art_program)
    ]
  end
end
