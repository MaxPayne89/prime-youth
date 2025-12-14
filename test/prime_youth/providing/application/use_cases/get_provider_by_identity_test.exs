defmodule PrimeYouth.Providing.Application.UseCases.GetProviderByIdentityTest do
  @moduledoc """
  Tests for the GetProviderByIdentity use case.

  Tests the orchestration of provider profile retrieval via the repository port.
  """

  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Providing.Application.UseCases.CreateProviderProfile
  alias PrimeYouth.Providing.Application.UseCases.GetProviderByIdentity
  alias PrimeYouth.Providing.Domain.Models.Provider

  # =============================================================================
  # execute/1 - Successful Retrieval
  # =============================================================================

  describe "execute/1 successful retrieval" do
    test "retrieves existing provider by identity_id" do
      identity_id = Ecto.UUID.generate()
      verified_at = ~U[2025-01-10 08:00:00Z]

      attrs = %{
        identity_id: identity_id,
        business_name: "Kids Sports Academy",
        description: "Youth sports training",
        phone: "+1987654321",
        website: "https://example.com",
        address: "123 Main St",
        logo_url: "https://example.com/logo.png",
        verified: true,
        verified_at: verified_at,
        categories: ["sports"]
      }

      {:ok, created_provider} = CreateProviderProfile.execute(attrs)

      assert {:ok, %Provider{} = retrieved_provider} = GetProviderByIdentity.execute(identity_id)
      assert retrieved_provider.id == created_provider.id
      assert retrieved_provider.identity_id == identity_id
      assert retrieved_provider.business_name == "Kids Sports Academy"
      assert retrieved_provider.description == "Youth sports training"
      assert retrieved_provider.phone == "+1987654321"
      assert retrieved_provider.website == "https://example.com"
      assert retrieved_provider.address == "123 Main St"
      assert retrieved_provider.logo_url == "https://example.com/logo.png"
      assert retrieved_provider.verified == true
      assert retrieved_provider.verified_at == verified_at
      assert retrieved_provider.categories == ["sports"]
    end

    test "retrieves correct provider when multiple exist" do
      first_identity = Ecto.UUID.generate()
      second_identity = Ecto.UUID.generate()

      {:ok, _first} =
        CreateProviderProfile.execute(%{
          identity_id: first_identity,
          business_name: "First Provider"
        })

      {:ok, second} =
        CreateProviderProfile.execute(%{
          identity_id: second_identity,
          business_name: "Second Provider"
        })

      assert {:ok, retrieved} = GetProviderByIdentity.execute(second_identity)
      assert retrieved.id == second.id
      assert retrieved.business_name == "Second Provider"
    end

    test "retrieves provider with all optional fields nil" do
      identity_id = Ecto.UUID.generate()

      {:ok, _created} =
        CreateProviderProfile.execute(%{
          identity_id: identity_id,
          business_name: "Minimal Provider"
        })

      assert {:ok, retrieved} = GetProviderByIdentity.execute(identity_id)
      assert retrieved.business_name == "Minimal Provider"
      assert is_nil(retrieved.description)
      assert is_nil(retrieved.phone)
      assert is_nil(retrieved.website)
      assert is_nil(retrieved.address)
      assert is_nil(retrieved.logo_url)
    end
  end

  # =============================================================================
  # execute/1 - Error Cases
  # =============================================================================

  describe "execute/1 error cases" do
    test "returns :not_found for non-existent identity_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = GetProviderByIdentity.execute(non_existent_id)
    end

    test "returns :not_found for each call with non-existent identity_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = GetProviderByIdentity.execute(non_existent_id)
      assert {:error, :not_found} = GetProviderByIdentity.execute(non_existent_id)
    end
  end
end
