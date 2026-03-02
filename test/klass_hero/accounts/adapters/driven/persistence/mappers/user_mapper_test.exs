defmodule KlassHero.Accounts.Adapters.Driven.Persistence.Mappers.UserMapperTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Accounts.Adapters.Driven.Persistence.Mappers.UserMapper
  alias KlassHero.Accounts.Domain.Models.User, as: DomainUser

  describe "to_domain/1" do
    test "converts User schema to domain model" do
      schema = user_fixture()

      domain_user = UserMapper.to_domain(schema)

      assert %DomainUser{} = domain_user
      assert domain_user.id == schema.id
      assert domain_user.email == schema.email
      assert domain_user.name == schema.name
      assert domain_user.locale == schema.locale
      assert domain_user.is_admin == schema.is_admin
      assert domain_user.intended_roles == schema.intended_roles
      assert domain_user.confirmed_at == schema.confirmed_at
    end

    test "coalesces nil intended_roles to empty list" do
      schema = %{user_fixture() | intended_roles: nil}

      domain_user = UserMapper.to_domain(schema)

      assert domain_user.intended_roles == []
    end

    test "excludes auth infrastructure fields" do
      schema = user_fixture() |> set_password()

      domain_user = UserMapper.to_domain(schema)

      refute Map.has_key?(domain_user, :password)
      refute Map.has_key?(domain_user, :hashed_password)
      refute Map.has_key?(domain_user, :authenticated_at)
    end
  end
end
