defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ConsentRepositoryTest do
  @moduledoc """
  Tests for the ConsentRepository adapter.
  """

  use KlassHero.DataCase, async: true

  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository
  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ConsentRepository
  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ParentProfileRepository
  alias KlassHero.Identity.Domain.Models.Consent

  defp create_parent do
    identity_id = Ecto.UUID.generate()
    {:ok, parent} = ParentProfileRepository.create_parent_profile(%{identity_id: identity_id})
    parent
  end

  defp create_child(parent) do
    {:ok, child} =
      ChildRepository.create(%{
        parent_id: parent.id,
        first_name: "Emma",
        last_name: "Smith",
        date_of_birth: ~D[2015-06-15]
      })

    child
  end

  describe "grant/1" do
    test "grants consent and returns domain entity" do
      parent = create_parent()
      child = create_child(parent)

      attrs = %{
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing",
        granted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      assert {:ok, %Consent{} = consent} = ConsentRepository.grant(attrs)
      assert is_binary(consent.id)
      assert consent.parent_id == parent.id
      assert consent.child_id == child.id
      assert consent.consent_type == "provider_data_sharing"
      assert %DateTime{} = consent.granted_at
      assert is_nil(consent.withdrawn_at)
    end

    test "returns changeset error for missing required fields" do
      assert {:error, %Ecto.Changeset{}} = ConsentRepository.grant(%{})
    end
  end

  describe "withdraw/1" do
    test "withdraws consent by setting withdrawn_at" do
      parent = create_parent()
      child = create_child(parent)

      {:ok, granted} =
        ConsentRepository.grant(%{
          parent_id: parent.id,
          child_id: child.id,
          consent_type: "provider_data_sharing",
          granted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert {:ok, %Consent{} = withdrawn} = ConsentRepository.withdraw(granted.id)
      assert %DateTime{} = withdrawn.withdrawn_at
      assert withdrawn.id == granted.id
    end

    test "returns :not_found for non-existent consent" do
      assert {:error, :not_found} = ConsentRepository.withdraw(Ecto.UUID.generate())
    end

    test "returns :not_found for invalid UUID" do
      assert {:error, :not_found} = ConsentRepository.withdraw("invalid-uuid")
    end
  end

  describe "get_active_for_child/2" do
    test "returns active consent for child and type" do
      parent = create_parent()
      child = create_child(parent)

      {:ok, granted} =
        ConsentRepository.grant(%{
          parent_id: parent.id,
          child_id: child.id,
          consent_type: "provider_data_sharing",
          granted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert {:ok, %Consent{} = found} =
               ConsentRepository.get_active_for_child(child.id, "provider_data_sharing")

      assert found.id == granted.id
    end

    test "does not return withdrawn consents" do
      parent = create_parent()
      child = create_child(parent)

      {:ok, granted} =
        ConsentRepository.grant(%{
          parent_id: parent.id,
          child_id: child.id,
          consent_type: "provider_data_sharing",
          granted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      ConsentRepository.withdraw(granted.id)

      assert {:error, :not_found} =
               ConsentRepository.get_active_for_child(child.id, "provider_data_sharing")
    end

    test "returns :not_found when no consent exists" do
      child_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               ConsentRepository.get_active_for_child(child_id, "provider_data_sharing")
    end
  end

  describe "list_active_by_child/1" do
    test "lists active consents for a child" do
      parent = create_parent()
      child = create_child(parent)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        ConsentRepository.grant(%{
          parent_id: parent.id,
          child_id: child.id,
          consent_type: "provider_data_sharing",
          granted_at: now
        })

      {:ok, _} =
        ConsentRepository.grant(%{
          parent_id: parent.id,
          child_id: child.id,
          consent_type: "photo",
          granted_at: now
        })

      consents = ConsentRepository.list_active_by_child(child.id)

      assert length(consents) == 2
      types = Enum.map(consents, & &1.consent_type)
      assert "photo" in types
      assert "provider_data_sharing" in types
    end

    test "excludes withdrawn consents from listing" do
      parent = create_parent()
      child = create_child(parent)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, to_withdraw} =
        ConsentRepository.grant(%{
          parent_id: parent.id,
          child_id: child.id,
          consent_type: "provider_data_sharing",
          granted_at: now
        })

      {:ok, _} =
        ConsentRepository.grant(%{
          parent_id: parent.id,
          child_id: child.id,
          consent_type: "photo",
          granted_at: now
        })

      ConsentRepository.withdraw(to_withdraw.id)

      consents = ConsentRepository.list_active_by_child(child.id)

      assert length(consents) == 1
      assert Enum.at(consents, 0).consent_type == "photo"
    end

    test "returns empty list when child has no consents" do
      assert ConsentRepository.list_active_by_child(Ecto.UUID.generate()) == []
    end
  end
end
