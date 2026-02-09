defmodule KlassHero.IdentityFixtures do
  @moduledoc """
  Test helpers for creating entities in the Identity bounded context.
  """

  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.ProviderProfileMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.StaffMemberMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Repo

  @doc """
  Creates a provider profile for testing.

  Uses the schema directly to insert into database, then maps to domain model.
  """
  def provider_profile_fixture(attrs \\ %{}) do
    defaults = %{
      identity_id: Ecto.UUID.generate(),
      business_name: "Test Provider #{System.unique_integer([:positive])}"
    }

    merged = Map.merge(defaults, Map.new(attrs))

    {:ok, schema} =
      %ProviderProfileSchema{}
      |> ProviderProfileSchema.changeset(merged)
      |> Repo.insert()

    ProviderProfileMapper.to_domain(schema)
  end

  @doc """
  Creates a staff member for testing.

  Uses the schema directly to insert into database, then maps to domain model.
  """
  def staff_member_fixture(attrs \\ %{}) do
    defaults = %{
      provider_id: attrs[:provider_id] || provider_profile_fixture().id,
      first_name: "Staff #{System.unique_integer([:positive])}",
      last_name: "Member"
    }

    merged = Map.merge(defaults, Map.new(attrs))

    {:ok, schema} =
      %StaffMemberSchema{}
      |> StaffMemberSchema.create_changeset(merged)
      |> Repo.insert()

    StaffMemberMapper.to_domain(schema)
  end
end
