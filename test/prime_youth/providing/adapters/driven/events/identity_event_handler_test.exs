defmodule PrimeYouth.Providing.Adapters.Driven.Events.IdentityEventHandlerTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Providing
  alias PrimeYouth.Providing.Adapters.Driven.Events.IdentityEventHandler
  alias PrimeYouth.Shared.Domain.Events.DomainEvent

  describe "subscribed_events/0" do
    test "subscribes to user_registered event" do
      assert IdentityEventHandler.subscribed_events() == [:user_registered]
    end
  end

  describe "handle_event/1 with user_registered event" do
    test "creates provider profile when 'provider' in intended_roles" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["provider"]
        })

      assert :ok = IdentityEventHandler.handle_event(event)

      # Verify provider profile was created with correct business_name
      assert {:ok, provider} = Providing.get_provider_by_identity(user_id)
      assert provider.identity_id == user_id
      assert provider.business_name == "Test User"
    end

    test "creates provider profile when both 'parent' and 'provider' in intended_roles" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Another User",
          intended_roles: ["parent", "provider"]
        })

      assert :ok = IdentityEventHandler.handle_event(event)

      # Verify provider profile was created with correct business_name
      assert {:ok, provider} = Providing.get_provider_by_identity(user_id)
      assert provider.identity_id == user_id
      assert provider.business_name == "Another User"
    end

    test "uses user name as business_name" do
      user_id = Ecto.UUID.generate()
      user_name = "John Doe's Activities"

      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "john@example.com",
          name: user_name,
          intended_roles: ["provider"]
        })

      assert :ok = IdentityEventHandler.handle_event(event)

      # Verify business_name matches user name
      assert {:ok, provider} = Providing.get_provider_by_identity(user_id)
      assert provider.business_name == user_name
    end

    test "ignores event when 'provider' not in intended_roles" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["parent"]
        })

      assert :ignore = IdentityEventHandler.handle_event(event)

      # Verify no provider profile was created
      assert {:error, :not_found} = Providing.get_provider_by_identity(user_id)
    end

    test "ignores event when intended_roles is empty" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: []
        })

      assert :ignore = IdentityEventHandler.handle_event(event)

      # Verify no provider profile was created
      assert {:error, :not_found} = Providing.get_provider_by_identity(user_id)
    end

    test "handles duplicate identity gracefully" do
      user_id = Ecto.UUID.generate()

      # Create provider profile first
      {:ok, _provider} =
        Providing.create_provider_profile(%{
          identity_id: user_id,
          business_name: "Existing Business"
        })

      # Try to create again via event
      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["provider"]
        })

      # Should return :ok even though profile already exists
      assert :ok = IdentityEventHandler.handle_event(event)

      # Verify original provider profile still exists (not replaced)
      assert {:ok, provider} = Providing.get_provider_by_identity(user_id)
      assert provider.identity_id == user_id
      assert provider.business_name == "Existing Business"
    end
  end

  describe "handle_event/1 with other events" do
    test "ignores user_confirmed event" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_confirmed, user_id, :user, %{
          email: "test@example.com",
          confirmed_at: ~U[2024-01-01 12:00:00Z]
        })

      assert :ignore = IdentityEventHandler.handle_event(event)

      # Verify no provider profile was created
      assert {:error, :not_found} = Providing.get_provider_by_identity(user_id)
    end

    test "ignores user_email_changed event" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_email_changed, user_id, :user, %{
          new_email: "new@example.com",
          previous_email: "old@example.com"
        })

      assert :ignore = IdentityEventHandler.handle_event(event)

      # Verify no provider profile was created
      assert {:error, :not_found} = Providing.get_provider_by_identity(user_id)
    end

    test "ignores events with nil aggregate_id" do
      event =
        DomainEvent.new(:user_registered, nil, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["provider"]
        })

      # Should handle gracefully and not crash
      # The actual Providing.create_provider_profile will fail, but we expect the retry logic to handle it
      result = IdentityEventHandler.handle_event(event)

      # Should return error tuple after retries
      assert {:error, _reason} = result
    end
  end

  describe "retry logic" do
    test "returns error after retries fail" do
      # Using nil identity_id to simulate a persistent failure
      event =
        DomainEvent.new(:user_registered, nil, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["provider"]
        })

      # Should return error after retries
      assert {:error, _reason} = IdentityEventHandler.handle_event(event)
    end
  end

  describe "edge cases" do
    test "handles missing name in payload gracefully" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          # name is missing
          intended_roles: ["provider"]
        })

      # Should attempt to create with empty business_name
      # This will likely fail validation, but should not crash
      result = IdentityEventHandler.handle_event(event)

      # Should return error after retries (business_name validation will fail)
      assert {:error, _reason} = result
    end
  end
end
