defmodule KlassHero.Participation.Adapters.Driven.ProgramCatalogContext.ProgramProviderResolverTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Participation.Adapters.Driven.ProgramCatalogContext.ProgramProviderResolver

  describe "resolve_provider_id/1" do
    test "returns provider_id for an existing program" do
      provider = KlassHero.Factory.insert(:provider_profile_schema)
      program = KlassHero.Factory.insert(:program_schema, provider_id: provider.id)

      assert {:ok, provider_id} = ProgramProviderResolver.resolve_provider_id(program.id)
      assert provider_id == provider.id
    end

    test "returns :program_not_found when program does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :program_not_found} =
               ProgramProviderResolver.resolve_provider_id(non_existent_id)
    end
  end
end
