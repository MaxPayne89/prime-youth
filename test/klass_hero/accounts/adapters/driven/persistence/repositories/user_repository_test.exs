defmodule KlassHero.Accounts.Adapters.Driven.Persistence.Repositories.UserRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Accounts.Adapters.Driven.Persistence.Repositories.UserRepository
  alias KlassHero.Accounts.Domain.Models.User, as: DomainUser

  describe "get_by_id/1" do
    test "returns domain user when found" do
      schema = user_fixture()

      assert {:ok, %DomainUser{} = user} = UserRepository.get_by_id(schema.id)
      assert user.id == schema.id
      assert user.email == schema.email
    end

    test "returns error when not found" do
      assert {:error, :not_found} =
               UserRepository.get_by_id("00000000-0000-0000-0000-000000000000")
    end
  end

  describe "get_by_email/1" do
    test "returns domain user when found" do
      schema = user_fixture()

      assert {:ok, %DomainUser{} = user} = UserRepository.get_by_email(schema.email)
      assert user.email == schema.email
    end

    test "returns nil when not found" do
      assert nil == UserRepository.get_by_email("nonexistent@example.com")
    end
  end

  describe "exists?/1" do
    test "returns true when user exists" do
      schema = user_fixture()
      assert UserRepository.exists?(schema.id)
    end

    test "returns false when user does not exist" do
      refute UserRepository.exists?("00000000-0000-0000-0000-000000000000")
    end
  end
end
