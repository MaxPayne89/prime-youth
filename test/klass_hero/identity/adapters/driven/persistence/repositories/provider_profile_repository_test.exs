defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepositoryTest do
  @moduledoc """
  Tests for the ProviderProfileRepository adapter.
  """

  use KlassHero.DataCase, async: true

  alias KlassHero.AccountsFixtures
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

    test "returns :duplicate_resource error when profile exists" do
      identity_id = Ecto.UUID.generate()
      attrs = %{identity_id: identity_id, business_name: "First Business"}

      assert {:ok, _} = ProviderProfileRepository.create_provider_profile(attrs)

      second_attrs = %{identity_id: identity_id, business_name: "Second Business"}

      assert {:error, :duplicate_resource} =
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

  describe "list_verified_ids/0" do
    test "returns empty list when no providers exist" do
      assert {:ok, []} = ProviderProfileRepository.list_verified_ids()
    end

    test "returns only verified provider IDs" do
      admin = AccountsFixtures.user_fixture(%{is_admin: true})

      {:ok, provider_1} =
        ProviderProfileRepository.create_provider_profile(%{
          identity_id: Ecto.UUID.generate(),
          business_name: "Verified Business"
        })

      {:ok, provider_2} =
        ProviderProfileRepository.create_provider_profile(%{
          identity_id: Ecto.UUID.generate(),
          business_name: "Unverified Business"
        })

      # Verify only provider_1
      {:ok, verified} = ProviderProfile.verify(provider_1, admin.id)
      {:ok, _} = ProviderProfileRepository.update(verified)

      assert {:ok, ids} = ProviderProfileRepository.list_verified_ids()
      assert provider_1.id in ids
      refute provider_2.id in ids
    end

    test "returns all verified provider IDs" do
      admin = AccountsFixtures.user_fixture(%{is_admin: true})

      {:ok, provider_1} =
        ProviderProfileRepository.create_provider_profile(%{
          identity_id: Ecto.UUID.generate(),
          business_name: "Business One"
        })

      {:ok, provider_2} =
        ProviderProfileRepository.create_provider_profile(%{
          identity_id: Ecto.UUID.generate(),
          business_name: "Business Two"
        })

      # Verify both
      {:ok, verified_1} = ProviderProfile.verify(provider_1, admin.id)
      {:ok, _} = ProviderProfileRepository.update(verified_1)
      {:ok, verified_2} = ProviderProfile.verify(provider_2, admin.id)
      {:ok, _} = ProviderProfileRepository.update(verified_2)

      assert {:ok, ids} = ProviderProfileRepository.list_verified_ids()
      assert length(ids) == 2
      assert provider_1.id in ids
      assert provider_2.id in ids
    end

    test "returns IDs as strings" do
      admin = AccountsFixtures.user_fixture(%{is_admin: true})

      {:ok, provider} =
        ProviderProfileRepository.create_provider_profile(%{
          identity_id: Ecto.UUID.generate(),
          business_name: "String ID Business"
        })

      {:ok, verified} = ProviderProfile.verify(provider, admin.id)
      {:ok, _} = ProviderProfileRepository.update(verified)

      assert {:ok, [id]} = ProviderProfileRepository.list_verified_ids()
      assert is_binary(id)
    end
  end
end
