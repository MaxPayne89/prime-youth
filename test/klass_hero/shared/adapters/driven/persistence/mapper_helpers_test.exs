defmodule KlassHero.Shared.Adapters.Driven.Persistence.MapperHelpersTest do
  use ExUnit.Case, async: true

  alias KlassHero.Shared.Adapters.Driven.Persistence.MapperHelpers

  describe "string_to_tier/2" do
    test "returns the atom for a valid parent tier string" do
      assert MapperHelpers.string_to_tier("explorer", :explorer) == :explorer
      assert MapperHelpers.string_to_tier("active", :explorer) == :active
    end

    test "returns the atom for a valid provider tier string" do
      assert MapperHelpers.string_to_tier("starter", :starter) == :starter
      assert MapperHelpers.string_to_tier("professional", :starter) == :professional
      assert MapperHelpers.string_to_tier("business_plus", :starter) == :business_plus
    end

    test "returns the default when the string is nil" do
      assert MapperHelpers.string_to_tier(nil, :explorer) == :explorer
    end

    test "returns the default for an unknown tier string" do
      assert MapperHelpers.string_to_tier("unknown_tier", :explorer) == :explorer
    end

    test "returns the default for an empty string" do
      assert MapperHelpers.string_to_tier("", :starter) == :starter
    end

    test "does not create new atoms from arbitrary strings" do
      # Verify the function is safe and won't raise for non-existent atoms
      result = MapperHelpers.string_to_tier("definitely_not_an_existing_atom_xyz123", :explorer)

      assert result == :explorer
    end
  end

  describe "tier_to_string/2" do
    test "converts a parent tier atom to its string representation" do
      assert MapperHelpers.tier_to_string(:explorer, "explorer") == "explorer"
      assert MapperHelpers.tier_to_string(:active, "explorer") == "active"
    end

    test "converts a provider tier atom to its string representation" do
      assert MapperHelpers.tier_to_string(:starter, "starter") == "starter"
      assert MapperHelpers.tier_to_string(:professional, "starter") == "professional"
      assert MapperHelpers.tier_to_string(:business_plus, "starter") == "business_plus"
    end

    test "returns the default string when tier is nil" do
      assert MapperHelpers.tier_to_string(nil, "explorer") == "explorer"
      assert MapperHelpers.tier_to_string(nil, "starter") == "starter"
    end
  end

  describe "normalize_subscription_tier/1" do
    test "converts atom subscription_tier to a string" do
      attrs = %{subscription_tier: :explorer, name: "Alice"}

      assert MapperHelpers.normalize_subscription_tier(attrs) == %{
               subscription_tier: "explorer",
               name: "Alice"
             }
    end

    test "converts provider tier atom to string" do
      attrs = %{subscription_tier: :business_plus}

      assert MapperHelpers.normalize_subscription_tier(attrs) == %{
               subscription_tier: "business_plus"
             }
    end

    test "leaves attrs unchanged when subscription_tier key is absent" do
      attrs = %{name: "Alice"}

      assert MapperHelpers.normalize_subscription_tier(attrs) == %{name: "Alice"}
    end

    test "leaves attrs unchanged when subscription_tier is nil" do
      attrs = %{subscription_tier: nil, name: "Alice"}

      assert MapperHelpers.normalize_subscription_tier(attrs) == %{
               subscription_tier: nil,
               name: "Alice"
             }
    end

    test "leaves attrs unchanged when subscription_tier is already a string" do
      attrs = %{subscription_tier: "explorer"}

      assert MapperHelpers.normalize_subscription_tier(attrs) == %{subscription_tier: "explorer"}
    end
  end

  describe "maybe_add_id/2" do
    test "adds the id to the attrs map when id is present" do
      attrs = %{name: "Alice"}

      assert MapperHelpers.maybe_add_id(attrs, "some-uuid") == %{id: "some-uuid", name: "Alice"}
    end

    test "returns attrs unchanged when id is nil" do
      attrs = %{name: "Alice"}

      assert MapperHelpers.maybe_add_id(attrs, nil) == %{name: "Alice"}
    end

    test "works with empty attrs map" do
      assert MapperHelpers.maybe_add_id(%{}, "abc-123") == %{id: "abc-123"}
    end

    test "overwrites existing id when a new id is provided" do
      attrs = %{id: "old-id", name: "Alice"}

      assert MapperHelpers.maybe_add_id(attrs, "new-id") == %{id: "new-id", name: "Alice"}
    end
  end
end
