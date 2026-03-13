defmodule KlassHero.Admin.QueriesTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Admin.Queries

  describe "list_providers_for_select/0" do
    test "returns providers as %{id, label} maps sorted by name" do
      _provider_b = insert(:provider_profile_schema, business_name: "Zebra Sports")
      _provider_a = insert(:provider_profile_schema, business_name: "Alpha Arts")

      result = Queries.list_providers_for_select()

      assert [first | _] = result
      assert Map.keys(first) |> Enum.sort() == [:id, :label]
      assert first.label == "Alpha Arts"

      labels = Enum.map(result, & &1.label)
      assert "Alpha Arts" in labels
      assert "Zebra Sports" in labels

      # Verify sort order
      alpha_idx = Enum.find_index(result, &(&1.label == "Alpha Arts"))
      zebra_idx = Enum.find_index(result, &(&1.label == "Zebra Sports"))
      assert alpha_idx < zebra_idx
    end

    test "returns empty list when no providers exist" do
      assert Queries.list_providers_for_select() == []
    end
  end

  describe "list_programs_for_select/0" do
    test "returns programs as %{id, label, provider_id} maps sorted by title" do
      provider = insert(:provider_profile_schema)
      insert(:program_schema, provider_id: provider.id, title: "Yoga Flow")
      insert(:program_schema, provider_id: provider.id, title: "Art Adventures")

      result = Queries.list_programs_for_select()

      assert [first | _] = result
      assert Map.keys(first) |> Enum.sort() == [:id, :label, :provider_id]
      assert first.label == "Art Adventures"
      assert first.provider_id == provider.id
    end

    test "returns empty list when no programs exist" do
      assert Queries.list_programs_for_select() == []
    end
  end
end
