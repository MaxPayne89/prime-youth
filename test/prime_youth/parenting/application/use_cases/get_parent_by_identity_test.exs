defmodule PrimeYouth.Parenting.Application.UseCases.GetParentByIdentityTest do
  @moduledoc """
  Tests for the GetParentByIdentity use case.

  Tests the orchestration of parent profile retrieval via the repository port.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Parenting.Application.UseCases.CreateParentProfile
  alias PrimeYouth.Parenting.Application.UseCases.GetParentByIdentity
  alias PrimeYouth.Parenting.Domain.Models.Parent

  # =============================================================================
  # execute/1 - Successful Retrieval
  # =============================================================================

  describe "execute/1 successful retrieval" do
    test "retrieves existing parent by identity_id" do
      identity_id = Ecto.UUID.generate()

      attrs = %{
        identity_id: identity_id,
        display_name: "Jane Doe",
        phone: "+1987654321",
        location: "Los Angeles, CA",
        notification_preferences: %{push: true}
      }

      {:ok, created_parent} = CreateParentProfile.execute(attrs)

      assert {:ok, %Parent{} = retrieved_parent} = GetParentByIdentity.execute(identity_id)
      assert retrieved_parent.id == created_parent.id
      assert retrieved_parent.identity_id == identity_id
      assert retrieved_parent.display_name == "Jane Doe"
      assert retrieved_parent.phone == "+1987654321"
      assert retrieved_parent.location == "Los Angeles, CA"
      assert retrieved_parent.notification_preferences == %{"push" => true}
    end

    test "retrieves correct parent when multiple exist" do
      first_identity = Ecto.UUID.generate()
      second_identity = Ecto.UUID.generate()

      {:ok, _first} =
        CreateParentProfile.execute(%{
          identity_id: first_identity,
          display_name: "First"
        })

      {:ok, second} =
        CreateParentProfile.execute(%{
          identity_id: second_identity,
          display_name: "Second"
        })

      assert {:ok, retrieved} = GetParentByIdentity.execute(second_identity)
      assert retrieved.id == second.id
      assert retrieved.display_name == "Second"
    end
  end

  # =============================================================================
  # execute/1 - Error Cases
  # =============================================================================

  describe "execute/1 error cases" do
    test "returns :not_found for non-existent identity_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = GetParentByIdentity.execute(non_existent_id)
    end

    test "returns :not_found for each call with non-existent identity_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = GetParentByIdentity.execute(non_existent_id)
      assert {:error, :not_found} = GetParentByIdentity.execute(non_existent_id)
    end
  end
end
