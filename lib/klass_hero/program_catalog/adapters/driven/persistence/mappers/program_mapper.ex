defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Mappers.ProgramMapper do
  @moduledoc """
  Maps between domain Program entities and ProgramSchema Ecto structs.

  This adapter provides bidirectional conversion:
  - to_domain/1: ProgramSchema → Program (for reading from database)
  - to_domain_list/1: [ProgramSchema] → [Program] (convenience for collections)
  - to_schema/1: Program → map (for update operations)
  """

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @doc """
  Converts an Ecto ProgramSchema to a domain Program entity.

  Returns the domain Program struct with all fields mapped from the schema.
  The ID is converted to a string to maintain domain independence from Ecto types.

  ## Examples

      iex> schema = %ProgramSchema{
      ...>   id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   title: "Art Adventures",
      ...>   description: "Creative art exploration",
      ...>   schedule: "Mon & Wed, 3:30-5:00 PM",
      ...>   age_range: "6-8 years",
      ...>   price: Decimal.new("120.00"),
      ...>   pricing_period: "per month",
      ...>   spots_available: 12,
      ...>   gradient_class: "from-purple-500 to-pink-500",
      ...>   icon_path: "/images/icons/art.svg",
      ...>   inserted_at: ~U[2025-11-15 10:00:00Z],
      ...>   updated_at: ~U[2025-11-15 10:00:00Z]
      ...> }
      iex> program = ProgramMapper.to_domain(schema)
      iex> program.title
      "Art Adventures"

  """
  @spec to_domain(ProgramSchema.t()) :: Program.t()
  def to_domain(%ProgramSchema{} = schema) do
    %Program{
      id: to_string(schema.id),
      title: schema.title,
      description: schema.description,
      schedule: schema.schedule,
      age_range: schema.age_range,
      price: schema.price,
      pricing_period: schema.pricing_period,
      spots_available: schema.spots_available,
      gradient_class: schema.gradient_class,
      icon_path: schema.icon_path,
      lock_version: schema.lock_version,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Converts a list of ProgramSchema structs to a list of domain Program entities.

  This is a convenience function for mapping collections returned from database queries.

  ## Examples

      iex> schemas = [
      ...>   %ProgramSchema{id: "id1", title: "Program 1", ...},
      ...>   %ProgramSchema{id: "id2", title: "Program 2", ...}
      ...> ]
      iex> programs = ProgramMapper.to_domain_list(schemas)
      iex> length(programs)
      2

  """
  @spec to_domain_list([ProgramSchema.t()]) :: [Program.t()]
  def to_domain_list(schemas) when is_list(schemas) do
    Enum.map(schemas, &to_domain/1)
  end

  @doc """
  Converts a domain Program entity to a map of attributes for update operations.

  Returns a map containing only the updatable fields. Excludes id, timestamps,
  and lock_version as these are managed by Ecto.

  ## Examples

      iex> program = %Program{
      ...>   id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   title: "Updated Art Adventures",
      ...>   description: "New description",
      ...>   schedule: "Mon & Wed, 3:30-5:00 PM",
      ...>   age_range: "6-8 years",
      ...>   price: Decimal.new("150.00"),
      ...>   pricing_period: "per month",
      ...>   spots_available: 10,
      ...>   gradient_class: "from-purple-500 to-pink-500",
      ...>   icon_path: "/images/icons/art.svg"
      ...> }
      iex> attrs = ProgramMapper.to_schema(program)
      iex> attrs.title
      "Updated Art Adventures"

  """
  def to_schema(%Program{} = program) do
    %{
      title: program.title,
      description: program.description,
      schedule: program.schedule,
      age_range: program.age_range,
      price: program.price,
      pricing_period: program.pricing_period,
      spots_available: program.spots_available,
      gradient_class: program.gradient_class,
      icon_path: program.icon_path
    }
  end
end
