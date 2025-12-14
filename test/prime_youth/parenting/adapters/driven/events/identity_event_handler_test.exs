defmodule PrimeYouth.Parenting.Adapters.Driven.Events.IdentityEventHandlerTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Parenting
  alias PrimeYouth.Parenting.Adapters.Driven.Events.IdentityEventHandler
  alias PrimeYouth.Shared.Domain.Events.DomainEvent

  describe "subscribed_events/0" do
    test "subscribes to user_registered event" do
      assert IdentityEventHandler.subscribed_events() == [:user_registered]
    end
  end

  describe "handle_event/1 with user_registered event" do
    test "creates parent profile when 'parent' in intended_roles" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["parent"]
        })

      assert :ok = IdentityEventHandler.handle_event(event)

      # Verify parent profile was created
      assert {:ok, parent} = Parenting.get_parent_by_identity(user_id)
      assert parent.identity_id == user_id
    end

    test "creates parent profile when both 'parent' and 'provider' in intended_roles" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["parent", "provider"]
        })

      assert :ok = IdentityEventHandler.handle_event(event)

      # Verify parent profile was created
      assert {:ok, parent} = Parenting.get_parent_by_identity(user_id)
      assert parent.identity_id == user_id
    end

    test "ignores event when 'parent' not in intended_roles" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["provider"]
        })

      assert :ignore = IdentityEventHandler.handle_event(event)

      # Verify no parent profile was created
      assert {:error, :not_found} = Parenting.get_parent_by_identity(user_id)
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

      # Verify no parent profile was created
      assert {:error, :not_found} = Parenting.get_parent_by_identity(user_id)
    end

    test "handles duplicate identity gracefully" do
      user_id = Ecto.UUID.generate()

      # Create parent profile first
      {:ok, _parent} = Parenting.create_parent_profile(%{identity_id: user_id})

      # Try to create again via event
      event =
        DomainEvent.new(:user_registered, user_id, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["parent"]
        })

      # Should return :ok even though profile already exists
      assert :ok = IdentityEventHandler.handle_event(event)

      # Verify only one parent profile exists
      assert {:ok, parent} = Parenting.get_parent_by_identity(user_id)
      assert parent.identity_id == user_id
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

      # Verify no parent profile was created
      assert {:error, :not_found} = Parenting.get_parent_by_identity(user_id)
    end

    test "ignores user_email_changed event" do
      user_id = Ecto.UUID.generate()

      event =
        DomainEvent.new(:user_email_changed, user_id, :user, %{
          new_email: "new@example.com",
          previous_email: "old@example.com"
        })

      assert :ignore = IdentityEventHandler.handle_event(event)

      # Verify no parent profile was created
      assert {:error, :not_found} = Parenting.get_parent_by_identity(user_id)
    end

    test "ignores events with nil aggregate_id" do
      event =
        DomainEvent.new(:user_registered, nil, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["parent"]
        })

      # Should handle gracefully and not crash
      # The actual Parenting.create_parent_profile will fail, but we expect the retry logic to handle it
      result = IdentityEventHandler.handle_event(event)

      # Should return error tuple after retries
      assert {:error, _reason} = result
    end
  end

  describe "retry logic" do
    # Note: Testing actual retry behavior with mocks would require more complex setup
    # These tests verify the handler behavior, actual retry testing would be integration tests

    test "returns error after retries fail" do
      # Using nil identity_id to simulate a persistent failure
      event =
        DomainEvent.new(:user_registered, nil, :user, %{
          email: "test@example.com",
          name: "Test User",
          intended_roles: ["parent"]
        })

      # Should return error after retries
      assert {:error, _reason} = IdentityEventHandler.handle_event(event)
    end
  end
end
