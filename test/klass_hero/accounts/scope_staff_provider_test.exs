defmodule KlassHero.Accounts.ScopeStaffProviderTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures
  import KlassHero.ProviderFixtures

  alias KlassHero.Accounts.Scope

  describe "resolve_roles/1 with staff_provider" do
    test "adds :staff_provider role when user is active staff member" do
      user = user_fixture(intended_roles: [:staff_provider])
      provider = provider_profile_fixture()
      _staff = staff_member_fixture(%{provider_id: provider.id, user_id: user.id, active: true})

      scope = Scope.for_user(user) |> Scope.resolve_roles()

      assert :staff_provider in scope.roles
      assert scope.staff_member != nil
      assert scope.staff_member.provider_id == provider.id
    end

    test "does not add :staff_provider when user has no staff membership" do
      user = user_fixture()

      scope = Scope.for_user(user) |> Scope.resolve_roles()

      refute :staff_provider in scope.roles
      assert scope.staff_member == nil
    end

    test "does not add :staff_provider when staff member is inactive" do
      user = user_fixture(intended_roles: [:staff_provider])
      provider = provider_profile_fixture()
      _staff = staff_member_fixture(%{provider_id: provider.id, user_id: user.id, active: false})

      scope = Scope.for_user(user) |> Scope.resolve_roles()

      refute :staff_provider in scope.roles
      assert scope.staff_member == nil
    end
  end

  describe "staff_provider?/1" do
    test "returns true when staff_member is present" do
      scope = %Scope{staff_member: %{id: "123"}}
      assert Scope.staff_provider?(scope)
    end

    test "returns false when staff_member is nil" do
      scope = %Scope{staff_member: nil}
      refute Scope.staff_provider?(scope)
    end
  end
end
