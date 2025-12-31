defmodule PrimeYouth.IdentityTest do
  @moduledoc """
  Integration tests for the Identity context public API.

  Tests the complete flow from context facade through use cases to repositories.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Identity
  alias PrimeYouth.Identity.Domain.Models.Child
  alias PrimeYouth.Identity.Domain.Models.ParentProfile
  alias PrimeYouth.Identity.Domain.Models.ProviderProfile

  # ============================================================================
  # Parent Profile Functions
  # ============================================================================

  describe "create_parent_profile/1" do
    test "creates parent profile through public API" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        display_name: "John Doe"
      }

      assert {:ok, %ParentProfile{} = profile} = Identity.create_parent_profile(attrs)
      assert profile.identity_id == attrs.identity_id
      assert profile.display_name == "John Doe"
    end

    test "returns validation error for invalid attrs" do
      attrs = %{identity_id: ""}

      assert {:error, {:validation_error, errors}} = Identity.create_parent_profile(attrs)
      assert "Identity ID cannot be empty" in errors
    end

    test "returns duplicate error when profile exists" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id}

      assert {:ok, _} = Identity.create_parent_profile(attrs)
      assert {:error, :duplicate_identity} = Identity.create_parent_profile(attrs)
    end
  end

  describe "get_parent_by_identity/1" do
    test "retrieves existing parent profile" do
      identity_id = Ecto.UUID.generate()
      {:ok, created} = Identity.create_parent_profile(%{identity_id: identity_id})

      assert {:ok, %ParentProfile{} = retrieved} = Identity.get_parent_by_identity(identity_id)
      assert retrieved.id == created.id
    end

    test "returns not_found for non-existent profile" do
      assert {:error, :not_found} = Identity.get_parent_by_identity(Ecto.UUID.generate())
    end
  end

  describe "has_parent_profile?/1" do
    test "returns true when profile exists" do
      identity_id = Ecto.UUID.generate()
      {:ok, _} = Identity.create_parent_profile(%{identity_id: identity_id})

      assert Identity.has_parent_profile?(identity_id) == true
    end

    test "returns false when profile does not exist" do
      assert Identity.has_parent_profile?(Ecto.UUID.generate()) == false
    end
  end

  # ============================================================================
  # Provider Profile Functions
  # ============================================================================

  describe "create_provider_profile/1" do
    test "creates provider profile through public API" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Kids Sports Academy"
      }

      assert {:ok, %ProviderProfile{} = profile} = Identity.create_provider_profile(attrs)
      assert profile.identity_id == attrs.identity_id
      assert profile.business_name == "Kids Sports Academy"
    end

    test "returns validation error for invalid attrs" do
      attrs = %{identity_id: Ecto.UUID.generate(), business_name: ""}

      assert {:error, {:validation_error, errors}} = Identity.create_provider_profile(attrs)
      assert "Business name cannot be empty" in errors
    end

    test "returns duplicate error when profile exists" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id, business_name: "My Business"}

      assert {:ok, _} = Identity.create_provider_profile(attrs)
      assert {:error, :duplicate_identity} = Identity.create_provider_profile(attrs)
    end
  end

  describe "get_provider_by_identity/1" do
    test "retrieves existing provider profile" do
      identity_id = Ecto.UUID.generate()

      {:ok, created} =
        Identity.create_provider_profile(%{
          identity_id: identity_id,
          business_name: "My Business"
        })

      assert {:ok, %ProviderProfile{} = retrieved} = Identity.get_provider_by_identity(identity_id)
      assert retrieved.id == created.id
    end

    test "returns not_found for non-existent profile" do
      assert {:error, :not_found} = Identity.get_provider_by_identity(Ecto.UUID.generate())
    end
  end

  describe "has_provider_profile?/1" do
    test "returns true when profile exists" do
      identity_id = Ecto.UUID.generate()

      {:ok, _} =
        Identity.create_provider_profile(%{
          identity_id: identity_id,
          business_name: "My Business"
        })

      assert Identity.has_provider_profile?(identity_id) == true
    end

    test "returns false when profile does not exist" do
      assert Identity.has_provider_profile?(Ecto.UUID.generate()) == false
    end
  end

  # ============================================================================
  # Children Functions
  # ============================================================================

  defp create_parent_for_children do
    identity_id = Ecto.UUID.generate()
    {:ok, parent} = Identity.create_parent_profile(%{identity_id: identity_id})
    parent
  end

  describe "get_children/1" do
    test "returns children for parent" do
      parent = create_parent_for_children()

      alias PrimeYouth.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository

      {:ok, _} =
        ChildRepository.create(%{
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      children = Identity.get_children(parent.id)

      assert length(children) == 1
      assert Enum.at(children, 0).first_name == "Emma"
    end

    test "returns empty list when no children" do
      parent = create_parent_for_children()
      children = Identity.get_children(parent.id)

      assert children == []
    end
  end

  describe "get_child_by_id/1" do
    test "retrieves existing child" do
      parent = create_parent_for_children()

      alias PrimeYouth.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository

      {:ok, created} =
        ChildRepository.create(%{
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith",
          date_of_birth: ~D[2015-06-15]
        })

      assert {:ok, %Child{} = retrieved} = Identity.get_child_by_id(created.id)
      assert retrieved.id == created.id
      assert retrieved.first_name == "Emma"
    end

    test "returns not_found for non-existent child" do
      assert {:error, :not_found} = Identity.get_child_by_id(Ecto.UUID.generate())
    end
  end
end
