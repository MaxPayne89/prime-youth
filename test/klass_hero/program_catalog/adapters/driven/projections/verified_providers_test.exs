defmodule KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProvidersTest do
  use KlassHero.DataCase, async: false

  alias KlassHero.AccountsFixtures
  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository
  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  # Use a unique name for each test to avoid conflicts with the supervision tree
  @test_server_name :verified_providers_test

  setup do
    pid = start_supervised!({VerifiedProviders, name: @test_server_name})
    {:ok, pid: pid}
  end

  describe "verified?/1" do
    test "returns false for unknown provider" do
      provider_id = Ecto.UUID.generate()
      refute VerifiedProviders.verified?(provider_id, @test_server_name)
    end

    test "returns true after receiving provider_verified event" do
      provider_id = Ecto.UUID.generate()

      # Trigger: Simulate the integration event published by Provider context
      # Why: VerifiedProviders projection should react to verification events
      # Outcome: Provider ID is added to the in-memory MapSet
      event =
        IntegrationEvent.new(
          :provider_verified,
          :provider,
          :provider,
          provider_id,
          %{provider_id: provider_id, business_name: "Test Business"}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:provider:provider_verified",
        {:integration_event, event}
      )

      # Synchronize: ensure GenServer has processed the broadcast
      _ = :sys.get_state(@test_server_name)

      assert VerifiedProviders.verified?(provider_id, @test_server_name)
    end

    test "returns false after receiving provider_unverified event" do
      provider_id = Ecto.UUID.generate()

      # Trigger: Provider gets verified first
      # Why: Must be verified before we can unverify
      # Outcome: Provider is in the verified set
      verify_event =
        IntegrationEvent.new(
          :provider_verified,
          :provider,
          :provider,
          provider_id,
          %{provider_id: provider_id, business_name: "Test Business"}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:provider:provider_verified",
        {:integration_event, verify_event}
      )

      _ = :sys.get_state(@test_server_name)
      assert VerifiedProviders.verified?(provider_id, @test_server_name)

      # Trigger: Provider loses verification
      # Why: Admin revokes verification status
      # Outcome: Provider ID is removed from the in-memory MapSet
      unverify_event =
        IntegrationEvent.new(
          :provider_unverified,
          :provider,
          :provider,
          provider_id,
          %{provider_id: provider_id, business_name: "Test Business"}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:provider:provider_unverified",
        {:integration_event, unverify_event}
      )

      _ = :sys.get_state(@test_server_name)
      refute VerifiedProviders.verified?(provider_id, @test_server_name)
    end

    test "handles multiple providers independently" do
      provider_1 = Ecto.UUID.generate()
      provider_2 = Ecto.UUID.generate()

      # Verify both providers
      for provider_id <- [provider_1, provider_2] do
        event =
          IntegrationEvent.new(
            :provider_verified,
            :provider,
            :provider,
            provider_id,
            %{provider_id: provider_id}
          )

        Phoenix.PubSub.broadcast(
          KlassHero.PubSub,
          "integration:provider:provider_verified",
          {:integration_event, event}
        )
      end

      _ = :sys.get_state(@test_server_name)
      assert VerifiedProviders.verified?(provider_1, @test_server_name)
      assert VerifiedProviders.verified?(provider_2, @test_server_name)

      # Unverify only provider_1
      unverify_event =
        IntegrationEvent.new(
          :provider_unverified,
          :provider,
          :provider,
          provider_1,
          %{provider_id: provider_1}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:provider:provider_unverified",
        {:integration_event, unverify_event}
      )

      _ = :sys.get_state(@test_server_name)
      refute VerifiedProviders.verified?(provider_1, @test_server_name)
      assert VerifiedProviders.verified?(provider_2, @test_server_name)
    end
  end

  describe "bootstrap from Provider context" do
    test "bootstraps verified providers from database on startup" do
      admin = AccountsFixtures.user_fixture(%{is_admin: true})

      # Create a provider and verify it directly in the database
      {:ok, provider} =
        ProviderProfileRepository.create_provider_profile(%{
          identity_id: Ecto.UUID.generate(),
          business_name: "Verified Business"
        })

      {:ok, verified} = ProviderProfile.verify(provider, admin.id)
      {:ok, _} = ProviderProfileRepository.update(verified)

      # Also create an unverified provider
      {:ok, unverified_provider} =
        ProviderProfileRepository.create_provider_profile(%{
          identity_id: Ecto.UUID.generate(),
          business_name: "Unverified Business"
        })

      # Start a new GenServer instance — it should bootstrap from DB
      bootstrap_name = :"bootstrap_test_#{System.unique_integer([:positive])}"
      bootstrap_pid = start_supervised!({VerifiedProviders, name: bootstrap_name}, id: :bootstrap)

      # Trigger: New GenServer bootstraps from Provider.list_verified_provider_ids/0
      # Why: On cold start, cache must be hydrated from the authoritative source
      # Outcome: Already-verified providers are immediately queryable
      _ = :sys.get_state(bootstrap_pid)

      assert VerifiedProviders.verified?(provider.id, bootstrap_name)
      refute VerifiedProviders.verified?(unverified_provider.id, bootstrap_name)
    end
  end

  describe "idempotency" do
    test "duplicate verification events are handled gracefully" do
      provider_id = Ecto.UUID.generate()

      # Send the same verification event twice
      event =
        IntegrationEvent.new(
          :provider_verified,
          :provider,
          :provider,
          provider_id,
          %{provider_id: provider_id}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:provider:provider_verified",
        {:integration_event, event}
      )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:provider:provider_verified",
        {:integration_event, event}
      )

      _ = :sys.get_state(@test_server_name)

      # Trigger: Multiple verification events for same provider
      # Why: Events may be replayed or duplicated
      # Outcome: MapSet handles duplicates naturally, provider remains verified
      assert VerifiedProviders.verified?(provider_id, @test_server_name)
    end

    test "unverifying non-existent provider is handled gracefully" do
      provider_id = Ecto.UUID.generate()

      # Trigger: Unverify event for provider not in the set
      # Why: Edge case handling - event ordering or missed events
      # Outcome: No crash, operation is a no-op
      event =
        IntegrationEvent.new(
          :provider_unverified,
          :provider,
          :provider,
          provider_id,
          %{provider_id: provider_id}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:provider:provider_unverified",
        {:integration_event, event}
      )

      _ = :sys.get_state(@test_server_name)
      refute VerifiedProviders.verified?(provider_id, @test_server_name)
    end
  end
end
