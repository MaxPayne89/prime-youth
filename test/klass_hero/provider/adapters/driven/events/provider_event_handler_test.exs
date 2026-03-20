defmodule KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandlerTest do
  use KlassHero.DataCase, async: true

  import ExUnit.CaptureLog

  alias KlassHero.AccountsFixtures
  alias KlassHero.Provider
  alias KlassHero.Provider.Adapters.Driven.Events.ProviderEventHandler

  describe "handle_event/1 for :user_registered" do
    test "creates provider profile when 'provider' in intended_roles" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      event = build_user_registered_event(user)
      assert {:ok, _profile} = ProviderEventHandler.handle_event(event)

      assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
      assert profile.subscription_tier == :starter
    end

    test "creates provider profile with selected tier" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      event = build_user_registered_event(user, provider_subscription_tier: "professional")
      assert {:ok, _profile} = ProviderEventHandler.handle_event(event)

      assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
      assert profile.subscription_tier == :professional
    end

    test "falls back to default tier on invalid tier string" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      log =
        capture_log(fn ->
          event = build_user_registered_event(user, provider_subscription_tier: "invalid_tier")
          assert {:ok, _profile} = ProviderEventHandler.handle_event(event)
        end)

      assert log =~ "Invalid provider tier"
      assert log =~ "invalid_tier"

      assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
      assert profile.subscription_tier == :starter
    end

    test "creates provider profile when tier is nil" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      event = build_user_registered_event(user, provider_subscription_tier: nil)
      assert {:ok, _profile} = ProviderEventHandler.handle_event(event)

      assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
      assert profile.subscription_tier == :starter
    end

    test "creates provider profile when tier is empty string" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      event = build_user_registered_event(user, provider_subscription_tier: "")
      assert {:ok, _profile} = ProviderEventHandler.handle_event(event)

      assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
      assert profile.subscription_tier == :starter
    end

    test "ignores event when 'provider' not in intended_roles" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:parent])

      event = build_user_registered_event(user, intended_roles: ["parent"])
      assert :ignore = ProviderEventHandler.handle_event(event)
    end
  end

  describe "handle_event/1 for :user_anonymized" do
    test "returns :ok (no-op)" do
      event = %{event_type: :user_anonymized, entity_id: Ecto.UUID.generate()}
      assert :ok = ProviderEventHandler.handle_event(event)
    end
  end

  describe "handle_event/1 for unknown events" do
    test "returns :ignore" do
      event = %{event_type: :unknown_event, entity_id: Ecto.UUID.generate()}
      assert :ignore = ProviderEventHandler.handle_event(event)
    end
  end

  describe "handle_event/1 for :user_confirmed" do
    test "creates provider profile when 'provider' in intended_roles" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      event = build_user_confirmed_event(user)
      assert {:ok, _profile} = ProviderEventHandler.handle_event(event)

      assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
      assert profile.subscription_tier == :starter
    end

    test "creates provider profile with selected tier" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      event = build_user_confirmed_event(user, provider_subscription_tier: "professional")
      assert {:ok, _profile} = ProviderEventHandler.handle_event(event)

      assert {:ok, profile} = Provider.get_provider_by_identity(user.id)
      assert profile.subscription_tier == :professional
    end

    test "returns :ok when provider profile already exists (idempotent)" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      # First call creates the profile
      registered_event = build_user_registered_event(user)
      assert {:ok, _profile} = ProviderEventHandler.handle_event(registered_event)

      # Second call via user_confirmed is idempotent
      confirmed_event =
        build_user_confirmed_event(user, provider_subscription_tier: "professional")

      assert :ok = ProviderEventHandler.handle_event(confirmed_event)

      # Only one profile exists
      assert {:ok, _profile} = Provider.get_provider_by_identity(user.id)
    end

    test "ignores event when 'provider' not in intended_roles" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:parent])

      event = build_user_confirmed_event(user, intended_roles: ["parent"])
      assert :ignore = ProviderEventHandler.handle_event(event)
    end
  end

  describe "subscribed_events/0" do
    test "includes :user_confirmed" do
      assert :user_confirmed in ProviderEventHandler.subscribed_events()
    end
  end

  # Helpers

  defp build_user_registered_event(user, opts \\ []) do
    intended_roles = Keyword.get(opts, :intended_roles, ["provider"])
    provider_tier = Keyword.get(opts, :provider_subscription_tier)

    %{
      event_type: :user_registered,
      entity_id: user.id,
      payload: %{
        intended_roles: intended_roles,
        name: user.name || "Test Provider",
        provider_subscription_tier: provider_tier
      }
    }
  end

  defp build_user_confirmed_event(user, opts \\ []) do
    intended_roles = Keyword.get(opts, :intended_roles, ["provider"])
    provider_tier = Keyword.get(opts, :provider_subscription_tier)

    %{
      event_type: :user_confirmed,
      entity_id: user.id,
      payload: %{
        intended_roles: intended_roles,
        name: user.name || "Test Provider",
        provider_subscription_tier: provider_tier
      }
    }
  end
end
