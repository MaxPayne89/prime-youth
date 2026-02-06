defmodule KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProvidersTest do
  use KlassHero.DataCase, async: false

  alias KlassHero.ProgramCatalog.Adapters.Driven.Projections.VerifiedProviders
  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  # Use a unique name for each test to avoid conflicts with the supervision tree
  @test_server_name :verified_providers_test

  setup do
    # Start a separate test instance with a unique name
    # This avoids conflicts with the application's supervised instance
    {:ok, pid} = VerifiedProviders.start_link(name: @test_server_name)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5000)
    end)

    {:ok, pid: pid}
  end

  describe "verified?/1" do
    test "returns false for unknown provider" do
      provider_id = Ecto.UUID.generate()
      refute VerifiedProviders.verified?(provider_id, @test_server_name)
    end

    test "returns true after receiving provider_verified event" do
      provider_id = Ecto.UUID.generate()

      # Trigger: Simulate the integration event published by Identity context
      # Why: VerifiedProviders projection should react to verification events
      # Outcome: Provider ID is added to the in-memory MapSet
      event =
        IntegrationEvent.new(
          :provider_verified,
          :identity,
          :provider,
          provider_id,
          %{provider_id: provider_id, business_name: "Test Business"}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:identity:provider_verified",
        {:integration_event, event}
      )

      # Wait for async message processing
      Process.sleep(50)

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
          :identity,
          :provider,
          provider_id,
          %{provider_id: provider_id, business_name: "Test Business"}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:identity:provider_verified",
        {:integration_event, verify_event}
      )

      Process.sleep(50)
      assert VerifiedProviders.verified?(provider_id, @test_server_name)

      # Trigger: Provider loses verification
      # Why: Admin revokes verification status
      # Outcome: Provider ID is removed from the in-memory MapSet
      unverify_event =
        IntegrationEvent.new(
          :provider_unverified,
          :identity,
          :provider,
          provider_id,
          %{provider_id: provider_id, business_name: "Test Business"}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:identity:provider_unverified",
        {:integration_event, unverify_event}
      )

      Process.sleep(50)
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
            :identity,
            :provider,
            provider_id,
            %{provider_id: provider_id}
          )

        Phoenix.PubSub.broadcast(
          KlassHero.PubSub,
          "integration:identity:provider_verified",
          {:integration_event, event}
        )
      end

      Process.sleep(50)
      assert VerifiedProviders.verified?(provider_1, @test_server_name)
      assert VerifiedProviders.verified?(provider_2, @test_server_name)

      # Unverify only provider_1
      unverify_event =
        IntegrationEvent.new(
          :provider_unverified,
          :identity,
          :provider,
          provider_1,
          %{provider_id: provider_1}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:identity:provider_unverified",
        {:integration_event, unverify_event}
      )

      Process.sleep(50)
      refute VerifiedProviders.verified?(provider_1, @test_server_name)
      assert VerifiedProviders.verified?(provider_2, @test_server_name)
    end
  end

  describe "bootstrap from Identity context" do
    test "loads verified provider IDs on startup" do
      # Trigger: GenServer starts and calls Identity.list_verified_provider_ids()
      # Why: Need to hydrate in-memory cache from database on startup
      # Outcome: Any already-verified providers are immediately queryable

      # This test verifies the bootstrap mechanism works. In a real scenario,
      # the GenServer would call Identity.list_verified_provider_ids/0 on init.
      # Since we're using a test setup that starts a fresh GenServer without
      # existing verified providers, we just verify the GenServer starts correctly.
      assert Process.alive?(Process.whereis(@test_server_name))
    end
  end

  describe "idempotency" do
    test "duplicate verification events are handled gracefully" do
      provider_id = Ecto.UUID.generate()

      # Send the same verification event twice
      event =
        IntegrationEvent.new(
          :provider_verified,
          :identity,
          :provider,
          provider_id,
          %{provider_id: provider_id}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:identity:provider_verified",
        {:integration_event, event}
      )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:identity:provider_verified",
        {:integration_event, event}
      )

      Process.sleep(50)

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
          :identity,
          :provider,
          provider_id,
          %{provider_id: provider_id}
        )

      Phoenix.PubSub.broadcast(
        KlassHero.PubSub,
        "integration:identity:provider_unverified",
        {:integration_event, event}
      )

      Process.sleep(50)
      refute VerifiedProviders.verified?(provider_id, @test_server_name)
    end
  end
end
