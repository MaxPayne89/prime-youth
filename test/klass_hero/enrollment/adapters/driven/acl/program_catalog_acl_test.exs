defmodule KlassHero.Enrollment.Adapters.Driven.ACL.ProgramCatalogACLTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.ACL.ProgramCatalogACL

  describe "list_program_titles_for_provider/1" do
    test "returns title-to-id map for provider's programs" do
      provider = insert(:provider_profile_schema)

      program1 =
        insert(:program_schema, provider_id: provider.id, title: "Ballsports & Parkour")

      program2 = insert(:program_schema, provider_id: provider.id, title: "Organic Arts")

      result = ProgramCatalogACL.list_program_titles_for_provider(provider.id)

      assert result == %{
               "Ballsports & Parkour" => program1.id,
               "Organic Arts" => program2.id
             }
    end

    test "excludes programs from other providers" do
      provider = insert(:provider_profile_schema)
      other_provider = insert(:provider_profile_schema)

      program = insert(:program_schema, provider_id: provider.id, title: "My Program")
      _other = insert(:program_schema, provider_id: other_provider.id, title: "Other Program")

      result = ProgramCatalogACL.list_program_titles_for_provider(provider.id)

      assert result == %{"My Program" => program.id}
    end

    test "returns empty map when provider has no programs" do
      provider = insert(:provider_profile_schema)

      assert ProgramCatalogACL.list_program_titles_for_provider(provider.id) == %{}
    end

    test "returns empty map for non-existent provider ID" do
      assert ProgramCatalogACL.list_program_titles_for_provider(Ecto.UUID.generate()) == %{}
    end
  end
end
