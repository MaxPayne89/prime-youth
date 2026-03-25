defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.StaffMemberRepositoryInvitationTest do
  @moduledoc """
  Tests for invitation-related repository functions on StaffMemberRepository.
  """

  use KlassHero.DataCase, async: true

  alias KlassHero.AccountsFixtures
  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.StaffMemberRepository
  alias KlassHero.Provider.Domain.Models.StaffMember
  alias KlassHero.ProviderFixtures

  describe "get_by_token_hash/1" do
    test "returns staff member when token hash matches and invitation_status is sent" do
      token_hash = :crypto.strong_rand_bytes(32)

      staff =
        ProviderFixtures.staff_member_fixture(%{
          invitation_status: :sent,
          invitation_token_hash: token_hash,
          invitation_sent_at: DateTime.utc_now()
        })

      assert {:ok, %StaffMember{} = found} = StaffMemberRepository.get_by_token_hash(token_hash)
      assert found.id == staff.id
      assert found.invitation_status == :sent
      assert found.invitation_token_hash == token_hash
    end

    test "returns :not_found when token hash does not match" do
      token_hash = :crypto.strong_rand_bytes(32)
      other_hash = :crypto.strong_rand_bytes(32)

      ProviderFixtures.staff_member_fixture(%{
        invitation_status: :sent,
        invitation_token_hash: token_hash,
        invitation_sent_at: DateTime.utc_now()
      })

      assert {:error, :not_found} = StaffMemberRepository.get_by_token_hash(other_hash)
    end

    test "returns :not_found when invitation_status is not sent" do
      token_hash = :crypto.strong_rand_bytes(32)

      ProviderFixtures.staff_member_fixture(%{
        invitation_status: :pending,
        invitation_token_hash: token_hash
      })

      assert {:error, :not_found} = StaffMemberRepository.get_by_token_hash(token_hash)
    end

    test "returns :not_found when no staff member exists with that token hash" do
      token_hash = :crypto.strong_rand_bytes(32)

      assert {:error, :not_found} = StaffMemberRepository.get_by_token_hash(token_hash)
    end
  end

  describe "get_active_by_user/1" do
    test "returns staff member when user_id matches and active is true" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      staff =
        ProviderFixtures.staff_member_fixture(%{
          user_id: user.id,
          active: true
        })

      assert {:ok, %StaffMember{} = found} = StaffMemberRepository.get_active_by_user(user.id)
      assert found.id == staff.id
      assert found.user_id == user.id
      assert found.active == true
    end

    test "returns :not_found when user_id does not match" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])
      other_user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      ProviderFixtures.staff_member_fixture(%{
        user_id: user.id,
        active: true
      })

      assert {:error, :not_found} = StaffMemberRepository.get_active_by_user(other_user.id)
    end

    test "returns :not_found when staff member is inactive" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      ProviderFixtures.staff_member_fixture(%{
        user_id: user.id,
        active: false
      })

      assert {:error, :not_found} = StaffMemberRepository.get_active_by_user(user.id)
    end

    test "returns :not_found when no staff member exists for user_id" do
      user = AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      assert {:error, :not_found} = StaffMemberRepository.get_active_by_user(user.id)
    end
  end
end
