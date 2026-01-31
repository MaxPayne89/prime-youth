defmodule KlassHero.Participation.Adapters.Driven.IdentityContext.ChildSafetyInfoResolverTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Participation.Adapters.Driven.IdentityContext.ChildSafetyInfoResolver

  describe "resolve_child_safety_info/1" do
    test "returns safety info when child has active provider_data_sharing consent" do
      parent = insert(:parent_profile_schema)

      child =
        insert(:child_schema,
          parent_id: parent.id,
          allergies: "Peanuts",
          support_needs: "ADHD accommodations",
          emergency_contact: "+49 123 456789"
        )

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing"
      )

      assert {:ok, safety_info} = ChildSafetyInfoResolver.resolve_child_safety_info(child.id)
      assert safety_info.allergies == "Peanuts"
      assert safety_info.support_needs == "ADHD accommodations"
      assert safety_info.emergency_contact == "+49 123 456789"
    end

    test "returns nil when child has no active consent" do
      child = insert(:child_schema, allergies: "Peanuts", support_needs: "ADHD accommodations")

      assert {:ok, nil} = ChildSafetyInfoResolver.resolve_child_safety_info(child.id)
    end

    test "returns nil safety fields when child has consent but nil optional fields" do
      parent = insert(:parent_profile_schema)

      child =
        insert(:child_schema,
          parent_id: parent.id,
          allergies: nil,
          support_needs: nil,
          emergency_contact: nil
        )

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing"
      )

      assert {:ok, safety_info} = ChildSafetyInfoResolver.resolve_child_safety_info(child.id)
      assert safety_info.allergies == nil
      assert safety_info.support_needs == nil
      assert safety_info.emergency_contact == nil
    end

    test "returns nil when consent has been withdrawn" do
      parent = insert(:parent_profile_schema)

      child =
        insert(:child_schema,
          parent_id: parent.id,
          allergies: "Gluten"
        )

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing",
        withdrawn_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      assert {:ok, nil} = ChildSafetyInfoResolver.resolve_child_safety_info(child.id)
    end

    test "returns nil for non-existent child (no consent record exists)" do
      # Non-existent child has no consent records, so consent check returns false
      # and the adapter returns nil (no safety data exposed)
      non_existent_id = Ecto.UUID.generate()

      assert {:ok, nil} =
               ChildSafetyInfoResolver.resolve_child_safety_info(non_existent_id)
    end
  end

  defp insert(factory, attrs \\ []) do
    KlassHero.Factory.insert(factory, attrs)
  end
end
