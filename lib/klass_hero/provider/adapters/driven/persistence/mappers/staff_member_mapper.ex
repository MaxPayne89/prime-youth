defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.StaffMemberMapper do
  @moduledoc """
  Maps between domain StaffMember entities and StaffMemberSchema Ecto structs.
  """

  import KlassHero.Shared.Adapters.Driven.Persistence.MapperHelpers,
    only: [maybe_add_id: 2]

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Provider.Domain.Models.StaffMember

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
      user_id: schema.user_id && to_string(schema.user_id),
      invitation_status: atomize_invitation_status(schema.invitation_status),
      invitation_token_hash: schema.invitation_token_hash,
      invitation_sent_at: schema.invitation_sent_at,
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
      active: staff.active,
      user_id: staff.user_id,
      invitation_status: staff.invitation_status && Atom.to_string(staff.invitation_status),
      invitation_token_hash: staff.invitation_token_hash,
      invitation_sent_at: staff.invitation_sent_at
    }
    |> maybe_add_id(staff.id)
  end

  defp atomize_invitation_status(nil), do: nil

  defp atomize_invitation_status(status) when is_binary(status),
    do: String.to_existing_atom(status)

  defp atomize_invitation_status(status) when is_atom(status), do: status
end
