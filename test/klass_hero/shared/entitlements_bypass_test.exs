defmodule KlassHero.Shared.EntitlementsBypassTest do
  use ExUnit.Case, async: false

  alias KlassHero.Accounts.Scope
  alias KlassHero.Family.Domain.Models.ParentProfile
  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.Shared.Adapters.Driven.FeatureFlags.StubFeatureFlagsAdapter
  alias KlassHero.Shared.Entitlements

  defp parent_with_tier(tier) do
    %ParentProfile{
      id: "parent-123",
      identity_id: "identity-123",
      subscription_tier: tier
    }
  end

  defp provider_with_tier(tier) do
    %ProviderProfile{
      id: "provider-123",
      identity_id: "identity-123",
      business_name: "Test Business",
      subscription_tier: tier
    }
  end

  describe "parent tier bypass enabled" do
    setup do
      start_supervised!({StubFeatureFlagsAdapter, name: StubFeatureFlagsAdapter})
      StubFeatureFlagsAdapter.set_enabled(:parent_tier_bypass)
      :ok
    end

    test "explorer parent gets unlimited booking cap" do
      parent = parent_with_tier(:explorer)
      assert Entitlements.monthly_booking_cap(parent) == :unlimited
    end

    test "explorer parent can create bookings at any count" do
      parent = parent_with_tier(:explorer)

      assert Entitlements.can_create_booking?(parent, 0)
      assert Entitlements.can_create_booking?(parent, 100)
      assert Entitlements.can_create_booking?(parent, 1000)
    end

    test "explorer parent gets 1 free cancellation" do
      parent = parent_with_tier(:explorer)
      assert Entitlements.free_cancellations_per_month(parent) == 1
    end

    test "explorer parent gets detailed progress" do
      parent = parent_with_tier(:explorer)
      assert Entitlements.progress_detail_level(parent) == :detailed
    end

    test "explorer parent can initiate messaging" do
      scope = %Scope{parent: parent_with_tier(:explorer), provider: nil}
      assert Entitlements.can_initiate_messaging?(scope)
    end

    test "explorer parent + starter provider can message when bypass enabled" do
      scope = %Scope{
        parent: parent_with_tier(:explorer),
        provider: provider_with_tier(:starter)
      }

      assert Entitlements.can_initiate_messaging?(scope)
    end

    test "active tier is unaffected (idempotent)" do
      parent = parent_with_tier(:active)

      assert Entitlements.monthly_booking_cap(parent) == :unlimited
      assert Entitlements.can_create_booking?(parent, 100)
      assert Entitlements.free_cancellations_per_month(parent) == 1
      assert Entitlements.progress_detail_level(parent) == :detailed
    end

    test "provider tiers are NOT affected" do
      provider = provider_with_tier(:starter)

      assert Entitlements.can_create_program?(provider, 0)
      refute Entitlements.can_create_program?(provider, 2)
      assert Entitlements.max_programs(provider) == 2
    end

    test "parent_tier_info/1 is NOT affected" do
      info = Entitlements.parent_tier_info(:explorer)

      assert info.monthly_booking_cap == 2
      assert info.free_cancellations == 0
      assert info.progress_level == :basic
      assert info.can_initiate_messaging == false
    end

    test "nil tier parent gets active limits when bypass enabled" do
      parent = parent_with_tier(nil)

      assert Entitlements.monthly_booking_cap(parent) == :unlimited
      assert Entitlements.can_create_booking?(parent, 100)
    end
  end

  describe "provider tier bypass enabled" do
    setup do
      start_supervised!({StubFeatureFlagsAdapter, name: StubFeatureFlagsAdapter})
      StubFeatureFlagsAdapter.set_enabled(:provider_tier_bypass)
      :ok
    end

    test "starter provider gets unlimited programs" do
      provider = provider_with_tier(:starter)
      assert Entitlements.max_programs(provider) == :unlimited
    end

    test "starter provider can create programs at any count" do
      provider = provider_with_tier(:starter)

      assert Entitlements.can_create_program?(provider, 0)
      assert Entitlements.can_create_program?(provider, 100)
    end

    test "starter provider gets unlimited team seats" do
      provider = provider_with_tier(:starter)
      assert Entitlements.team_seats_allowed(provider) == :unlimited
    end

    test "starter provider can add team members at any count" do
      provider = provider_with_tier(:starter)

      assert Entitlements.can_add_team_member?(provider, 0)
      assert Entitlements.can_add_team_member?(provider, 100)
    end

    test "starter provider gets business_plus commission rate" do
      provider = provider_with_tier(:starter)
      assert Entitlements.commission_rate(provider) == 0.08
    end

    test "starter provider gets all media types" do
      provider = provider_with_tier(:starter)

      assert Entitlements.media_entitlements(provider) == [
               :avatar,
               :gallery,
               :video,
               :promotional
             ]
    end

    test "starter provider can initiate messaging" do
      scope = %Scope{parent: nil, provider: provider_with_tier(:starter)}
      assert Entitlements.can_initiate_messaging?(scope)
    end

    test "business_plus tier is unaffected (idempotent)" do
      provider = provider_with_tier(:business_plus)

      assert Entitlements.max_programs(provider) == :unlimited
      assert Entitlements.can_create_program?(provider, 100)
      assert Entitlements.team_seats_allowed(provider) == :unlimited
      assert Entitlements.commission_rate(provider) == 0.08
    end

    test "provider_tier_info/1 is NOT affected" do
      info = Entitlements.provider_tier_info(:starter)

      assert info.max_programs == 2
      assert info.commission_rate == 0.18
      assert info.media == [:avatar]
      assert info.team_seats == 1
      assert info.can_initiate_messaging == false
    end

    test "parent tiers are NOT affected" do
      parent = parent_with_tier(:explorer)

      assert Entitlements.monthly_booking_cap(parent) == 2
      refute Entitlements.can_create_booking?(parent, 2)
    end

    test "nil tier provider gets business_plus limits when bypass enabled" do
      provider = provider_with_tier(nil)

      assert Entitlements.max_programs(provider) == :unlimited
      assert Entitlements.team_seats_allowed(provider) == :unlimited
    end
  end

  describe "fail-closed behavior — parent bypass" do
    test "reverts to normal enforcement when flag is explicitly disabled" do
      start_supervised!({StubFeatureFlagsAdapter, name: StubFeatureFlagsAdapter})
      StubFeatureFlagsAdapter.set_enabled(:parent_tier_bypass)

      parent = parent_with_tier(:explorer)
      assert Entitlements.monthly_booking_cap(parent) == :unlimited

      StubFeatureFlagsAdapter.set_disabled(:parent_tier_bypass)

      assert Entitlements.monthly_booking_cap(parent) == 2
      refute Entitlements.can_create_booking?(parent, 2)
    end

    test "reverts to normal enforcement when flag system unavailable" do
      start_supervised!({StubFeatureFlagsAdapter, name: StubFeatureFlagsAdapter})
      StubFeatureFlagsAdapter.set_enabled(:parent_tier_bypass)

      parent = parent_with_tier(:explorer)
      assert Entitlements.monthly_booking_cap(parent) == :unlimited

      Agent.stop(StubFeatureFlagsAdapter)

      assert Entitlements.monthly_booking_cap(parent) == 2
      refute Entitlements.can_create_booking?(parent, 2)
    end
  end

  describe "fail-closed behavior — provider bypass" do
    test "reverts to normal enforcement when flag is explicitly disabled" do
      start_supervised!({StubFeatureFlagsAdapter, name: StubFeatureFlagsAdapter})
      StubFeatureFlagsAdapter.set_enabled(:provider_tier_bypass)

      provider = provider_with_tier(:starter)
      assert Entitlements.max_programs(provider) == :unlimited

      StubFeatureFlagsAdapter.set_disabled(:provider_tier_bypass)

      assert Entitlements.max_programs(provider) == 2
      refute Entitlements.can_create_program?(provider, 2)
    end

    test "reverts to normal enforcement when flag system unavailable" do
      start_supervised!({StubFeatureFlagsAdapter, name: StubFeatureFlagsAdapter})
      StubFeatureFlagsAdapter.set_enabled(:provider_tier_bypass)

      provider = provider_with_tier(:starter)
      assert Entitlements.max_programs(provider) == :unlimited

      Agent.stop(StubFeatureFlagsAdapter)

      assert Entitlements.max_programs(provider) == 2
      refute Entitlements.can_create_program?(provider, 2)
    end
  end
end
