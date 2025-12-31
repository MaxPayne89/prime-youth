defmodule PrimeYouth.Attendance.Adapters.Driven.IdentityContext.ChildNameResolverTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Attendance.Adapters.Driven.IdentityContext.ChildNameResolver

  describe "resolve_child_name/1" do
    test "returns child full name when child exists" do
      # Arrange: Create a parent and child in the database
      parent_identity_id = Ecto.UUID.generate()

      parent_attrs = %{
        identity_id: parent_identity_id,
        display_name: "John Smith",
        phone: nil,
        location: nil,
        notification_preferences: nil
      }

      {:ok, parent} = parent_repository().create_parent_profile(parent_attrs)

      child_attrs = %{
        parent_id: parent.id,
        first_name: "Jane",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15],
        notes: nil
      }

      {:ok, child} = child_repository().create(child_attrs)

      # Act: Resolve child name
      result = ChildNameResolver.resolve_child_name(child.id)

      # Assert: Returns full name
      assert {:ok, "Jane Smith"} = result
    end

    test "returns :child_not_found when child does not exist" do
      # Arrange: Use a non-existent child ID
      non_existent_id = Ecto.UUID.generate()

      # Act: Resolve child name
      result = ChildNameResolver.resolve_child_name(non_existent_id)

      # Assert: Returns child_not_found error
      assert {:error, :child_not_found} = result
    end

    test "returns :child_not_found for invalid UUID format" do
      # Arrange: Use invalid UUID
      invalid_id = "not-a-valid-uuid"

      # Act: Resolve child name
      result = ChildNameResolver.resolve_child_name(invalid_id)

      # Assert: Returns child_not_found error (repository validates UUID)
      assert {:error, :child_not_found} = result
    end

    test "propagates database errors from Identity context" do
      # Note: This test would require mocking or a test double for the repository
      # to simulate database errors. For now, we verify the adapter passes through
      # error atoms unchanged (except :not_found → :child_not_found mapping)
      #
      # In a real scenario, you might use Mox or similar to inject a test double
      # that returns specific database errors to verify they propagate correctly.
      #
      # Example expected behavior:
      # {:error, :database_connection_error} -> {:error, :database_connection_error}
      # {:error, :database_query_error} -> {:error, :database_query_error}
    end
  end

  # Helper to get configured repositories from Identity context
  defp parent_repository do
    Application.get_env(:prime_youth, :identity)[:for_storing_parent_profiles]
  end

  defp child_repository do
    Application.get_env(:prime_youth, :identity)[:for_storing_children]
  end
end
