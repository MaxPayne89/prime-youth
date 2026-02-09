defmodule KlassHero.Identity.Adapters.Driven.Persistence.Mappers.StaffMemberMapper do
  @moduledoc """
  Maps between domain StaffMember entities and StaffMemberSchema Ecto structs.
  """

  import KlassHero.Identity.Adapters.Driven.Persistence.Mappers.MapperHelpers,
    only: [maybe_add_id: 2]

  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Identity.Domain.Models.StaffMember

  @spec to_domain(StaffMemberSchema.t()) :: StaffMember.t()
  def to_domain(%StaffMemberSchema{} = schema) do
    %StaffMember{
      id: to_string(schema.id),
      provider_id: to_string(schema.provider_id),
      first_name: schema.first_name,
      last_name: schema.last_name,
      role: schema.role,
      email: schema.email,
      bio: schema.bio,
      headshot_url: schema.headshot_url,
      tags: schema.tags || [],
      qualifications: schema.qualifications || [],
      active: schema.active,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @spec to_schema(StaffMember.t()) :: map()
  def to_schema(%StaffMember{} = staff) do
    %{
      provider_id: staff.provider_id,
      first_name: staff.first_name,
      last_name: staff.last_name,
      role: staff.role,
      email: staff.email,
      bio: staff.bio,
      headshot_url: staff.headshot_url,
      tags: staff.tags,
      qualifications: staff.qualifications,
      active: staff.active
    }
    |> maybe_add_id(staff.id)
  end

  @spec to_domain_list([StaffMemberSchema.t()]) :: [StaffMember.t()]
  def to_domain_list(schemas) when is_list(schemas), do: Enum.map(schemas, &to_domain/1)
end
