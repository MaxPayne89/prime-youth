defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepositoryTest do
  @moduledoc """
  Tests for the ProviderProfileRepository adapter.
  """

  use KlassHero.DataCase, async: true

  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository
  alias KlassHero.Identity.Domain.Models.ProviderProfile

  describe "create_provider_profile/1" do
    test "creates provider profile and returns domain entity" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "Kids Sports Academy",
        description: "Premier youth sports training",
        phone: "+1234567890",
        website: "https://example.com",
        address: "123 Main St",
        categories: ["sports", "outdoor"]
      }

      assert {:ok, %ProviderProfile{} = profile} =
               ProviderProfileRepository.create_provider_profile(attrs)

      assert is_binary(profile.id)
      assert profile.identity_id == attrs.identity_id
      assert profile.business_name == "Kids Sports Academy"
      assert profile.verified == false
      assert %DateTime{} = profile.inserted_at
    end

    test "creates provider profile with minimal fields" do
      attrs = %{
        identity_id: Ecto.UUID.generate(),
        business_name: "My Business"
      }

      assert {:ok, %ProviderProfile{} = profile} =
               ProviderProfileRepository.create_provider_profile(attrs)

      assert is_binary(profile.id)
      assert profile.business_name == "My Business"
    end

    test "returns :duplicate_identity error when profile exists" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id, business_name: "First Business"}

      assert {:ok, _} = ProviderProfileRepository.create_provider_profile(attrs)

      second_attrs = %{identity_id: identity_id, business_name: "Second Business"}

      assert {:error, :duplicate_identity} =
               ProviderProfileRepository.create_provider_profile(second_attrs)
    end
  end

  describe "get_by_identity_id/1" do
    test "retrieves existing provider profile" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id, business_name: "My Business"}

      {:ok, created} = ProviderProfileRepository.create_provider_profile(attrs)

      assert {:ok, %ProviderProfile{} = retrieved} =
               ProviderProfileRepository.get_by_identity_id(identity_id)

      assert retrieved.id == created.id
      assert retrieved.business_name == "My Business"
    end

    test "returns :not_found for non-existent identity_id" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = ProviderProfileRepository.get_by_identity_id(non_existent_id)
    end
  end

  describe "has_profile?/1" do
    test "returns true when profile exists" do
      identity_id = Ecto.UUID.generate()

      {:ok, _} =
        ProviderProfileRepository.create_provider_profile(%{
          identity_id: identity_id,
          business_name: "My Business"
        })

      assert ProviderProfileRepository.has_profile?(identity_id) == true
    end

    test "returns false when profile does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert ProviderProfileRepository.has_profile?(non_existent_id) == false
    end
  end
end
