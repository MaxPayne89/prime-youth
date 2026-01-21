defmodule KlassHero.Accounts.ScopeTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Accounts.Scope
  alias KlassHero.Identity

  describe "for_user/1" do
    test "creates scope with user" do
      user = user_fixture()
      scope = Scope.for_user(user)

      assert %Scope{} = scope
      assert scope.user == user
      assert scope.roles == []
      assert scope.parent == nil
      assert scope.provider == nil
    end

    test "returns nil for nil user" do
      assert Scope.for_user(nil) == nil
    end
  end

  describe "resolve_roles/1" do
    test "returns scope unchanged for nil user" do
      scope = %Scope{user: nil}
      resolved = Scope.resolve_roles(scope)

      assert resolved == scope
      assert resolved.roles == []
      assert resolved.parent == nil
      assert resolved.provider == nil
    end

    test "user with no profiles returns empty roles" do
      user = user_fixture()
      scope = Scope.for_user(user)
      resolved = Scope.resolve_roles(scope)

      assert resolved.roles == []
      assert resolved.parent == nil
      assert resolved.provider == nil
    end

    test "user with parent profile only returns parent role" do
      user = user_fixture()

      {:ok, parent} =
        Identity.create_parent_profile(%{
          identity_id: user.id,
          display_name: "Test Parent"
        })

      scope = Scope.for_user(user)
      resolved = Scope.resolve_roles(scope)

      assert resolved.roles == [:parent]
      assert resolved.parent.id == parent.id
      assert resolved.parent.identity_id == user.id
      assert resolved.provider == nil
    end

    test "user with provider profile only returns provider role" do
      user = user_fixture()

      {:ok, provider} =
        Identity.create_provider_profile(%{
          identity_id: user.id,
          business_name: "Test Provider"
        })

      scope = Scope.for_user(user)
      resolved = Scope.resolve_roles(scope)

      assert resolved.roles == [:provider]
      assert resolved.parent == nil
      assert resolved.provider.id == provider.id
      assert resolved.provider.identity_id == user.id
    end

    test "user with both profiles returns both roles" do
      user = user_fixture()

      {:ok, parent} =
        Identity.create_parent_profile(%{
          identity_id: user.id,
          display_name: "Test Parent"
        })

      {:ok, provider} =
        Identity.create_provider_profile(%{
          identity_id: user.id,
          business_name: "Test Provider"
        })

      scope = Scope.for_user(user)
      resolved = Scope.resolve_roles(scope)

      assert resolved.roles == [:provider, :parent]
      assert resolved.parent.id == parent.id
      assert resolved.provider.id == provider.id
    end
  end

  describe "has_role?/2" do
    test "returns true when role exists" do
      scope = %Scope{roles: [:parent, :provider]}

      assert Scope.has_role?(scope, :parent)
      assert Scope.has_role?(scope, :provider)
    end

    test "returns false when role doesn't exist" do
      scope = %Scope{roles: [:parent]}

      refute Scope.has_role?(scope, :provider)
      refute Scope.has_role?(scope, :admin)
    end

    test "handles empty roles list" do
      scope = %Scope{roles: []}

      refute Scope.has_role?(scope, :parent)
      refute Scope.has_role?(scope, :provider)
    end
  end

  describe "parent?/1" do
    test "returns true when parent profile exists" do
      user = user_fixture()

      {:ok, parent} =
        Identity.create_parent_profile(%{
          identity_id: user.id,
          display_name: "Test Parent"
        })

      scope = %Scope{parent: parent}

      assert Scope.parent?(scope)
    end

    test "returns false when parent profile is nil" do
      scope = %Scope{parent: nil}

      refute Scope.parent?(scope)
    end
  end

  describe "provider?/1" do
    test "returns true when provider profile exists" do
      user = user_fixture()

      {:ok, provider} =
        Identity.create_provider_profile(%{
          identity_id: user.id,
          business_name: "Test Provider"
        })

      scope = %Scope{provider: provider}

      assert Scope.provider?(scope)
    end

    test "returns false when provider profile is nil" do
      scope = %Scope{provider: nil}

      refute Scope.provider?(scope)
    end
  end

  # Test helper
  defp user_fixture(attrs \\ %{}) do
    unique_email = "user#{System.unique_integer()}@example.com"

    {:ok, user} =
      attrs
      |> Enum.into(%{
        name: "Test User",
        email: unique_email,
        password: "ValidPassword123!"
      })
      |> KlassHero.Accounts.register_user()

    user
  end
end
